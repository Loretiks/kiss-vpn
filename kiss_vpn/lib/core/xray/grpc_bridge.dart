import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'xray_config.dart';
import 'xray_process.dart';

/// Bridges vless+grpc proxies through a sidecar xray-core instance so the
/// gRPC traffic actually uses bidirectional streaming. Mihomo's clash-meta
/// gRPC transport is unary-only and the server (xray on the kissmain.ru
/// side) responds with `rpc error: code = Canceled` — see project memory
/// `project-mihomo-grpc-limitation`.
///
/// Flow on every (re)connect:
///   1. Walk the panel's Clash YAML, find vless proxies with `network: grpc`.
///   2. Allocate a local socks5 port per such proxy.
///   3. Generate an xray JSON with one inbound + outbound per proxy (the
///      outbound is the real vless+grpc upstream, `multiMode: true`).
///   4. Start xray as a sidecar process.
///   5. Rewrite the panel YAML: each grpc proxy entry is replaced with a
///      `type: socks5` stub pointing at `127.0.0.1:<local-port>`. Mihomo now
///      tunnels grpc traffic through xray transparently.
///
/// If the YAML has no grpc proxies, nothing is started and the YAML is
/// returned unchanged. Disconnect tears down the xray process.
class GrpcBridge {
  GrpcBridge();

  static const int _basePort = 12000;

  final XrayProcess _proc = XrayProcess();
  bool _running = false;

  bool get isActive => _running;

  /// Rewrites [yaml] so any vless+grpc proxies are funneled through a local
  /// xray sidecar and returns the modified YAML. Starts xray as a side
  /// effect when at least one grpc proxy is present.
  ///
  /// Failure mode: if YAML parsing or xray startup fails, returns the
  /// original yaml unmodified so the connect flow still has a chance to
  /// proceed (the grpc proxies just won't work — same as today).
  Future<String> setup(String yaml, {required String workDir}) async {
    await teardown();

    final YamlDocument doc;
    try {
      doc = loadYamlDocument(yaml);
    } catch (_) {
      return yaml;
    }
    final root = doc.contents;
    if (root is! YamlMap) return yaml;
    final proxiesNode = root['proxies'];
    if (proxiesNode is! YamlList) return yaml;

    final outs = <XrayOutbound>[];
    final patches = <_Patch>[];
    var nextPort = _basePort;

    for (final entryNode in proxiesNode.nodes) {
      if (entryNode is! YamlMap) continue;
      final type = entryNode['type']?.toString().toLowerCase();
      final network = entryNode['network']?.toString().toLowerCase();
      if (type != 'vless' || network != 'grpc') continue;

      final name = entryNode['name']?.toString();
      final server = entryNode['server']?.toString();
      final port = (entryNode['port'] as num?)?.toInt();
      final uuid = entryNode['uuid']?.toString();
      final grpcOpts = entryNode['grpc-opts'];
      final serviceName = grpcOpts is YamlMap
          ? grpcOpts['grpc-service-name']?.toString() ?? ''
          : '';
      if (name == null || server == null || port == null || uuid == null) {
        continue;
      }

      final reality = entryNode['reality-opts'];
      final hasReality = reality is YamlMap;
      final hasTls = entryNode['tls'] == true || hasReality;
      final security = hasReality
          ? 'reality'
          : (hasTls ? 'tls' : null);

      final localPort = nextPort++;
      outs.add(XrayOutbound(
        tag: _safeTag(name, outs.length),
        localPort: localPort,
        address: server,
        port: port,
        uuid: uuid,
        serviceName: serviceName,
        security: security,
        serverName: entryNode['servername']?.toString() ??
            entryNode['sni']?.toString(),
        fingerprint: entryNode['client-fingerprint']?.toString(),
        realityPublicKey:
            hasReality ? reality['public-key']?.toString() : null,
        realityShortId:
            hasReality ? reality['short-id']?.toString() : null,
        flow: entryNode['flow']?.toString(),
      ));

      final origSlice = yaml.substring(
          entryNode.span.start.offset, entryNode.span.end.offset);
      // YamlMap.span swallows whitespace up to the next sibling — preserve
      // it so the rewritten YAML keeps its line breaks + indentation for
      // whatever follows (next proxy entry, blank line, or `proxy-groups:`).
      final trailingWs =
          RegExp(r'(\s*)$').firstMatch(origSlice)?.group(1) ?? '';
      patches.add(_Patch(
        start: entryNode.span.start.offset,
        end: entryNode.span.end.offset,
        replacement: _buildSocks5Stub(
              name: name,
              localPort: localPort,
              original: origSlice,
            ) +
            trailingWs,
      ));
    }

    if (outs.isEmpty) return yaml;

    // Write xray config + start sidecar.
    final cfgDir = Directory(p.join(workDir, 'xray'));
    if (!await cfgDir.exists()) await cfgDir.create(recursive: true);
    final cfgPath = p.join(cfgDir.path, 'config.json');
    await File(cfgPath).writeAsString(buildXrayConfig(outs));

    try {
      await _proc.start(configPath: cfgPath);
      _running = true;
    } catch (_) {
      // Couldn't bring xray up — fall back to original YAML rather than
      // shipping a Mihomo config that points at sockets nothing is listening
      // on.
      _running = false;
      return yaml;
    }

    // Apply patches end-to-start so earlier offsets stay valid.
    patches.sort((a, b) => b.start.compareTo(a.start));
    var out = yaml;
    for (final patch in patches) {
      out = out.substring(0, patch.start) +
          patch.replacement +
          out.substring(patch.end);
    }
    return out;
  }

  Future<void> teardown() async {
    if (!_running && !_proc.isRunning) return;
    await _proc.stop();
    _running = false;
  }

  // ---- helpers ---------------------------------------------------------

  /// xray inbound/outbound tags must be unique. Names from the panel can
  /// contain spaces, emoji, parens — strip to ASCII alnum and disambiguate
  /// by index if the result collides.
  static String _safeTag(String name, int index) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
    if (cleaned.isEmpty) return 'p$index';
    return '${cleaned}_$index';
  }

  /// Build the socks5 stub that replaces a grpc proxy entry. Matches the
  /// indent of the original entry so YAML layout stays consistent.
  static String _buildSocks5Stub({
    required String name,
    required int localPort,
    required String original,
  }) {
    // The original substring starts at the first key (`name:`) — back-figure
    // the field indent by reading the leading whitespace of the second line.
    var indent = '    ';
    final nl = original.indexOf('\n');
    if (nl >= 0) {
      final m = RegExp(r'^( +)').firstMatch(original.substring(nl + 1));
      if (m != null) indent = m.group(1)!;
    }
    return 'name: ${_quoteYaml(name)}\n'
        '${indent}type: socks5\n'
        '${indent}server: 127.0.0.1\n'
        '${indent}port: $localPort\n'
        '${indent}udp: true';
  }

  static String _quoteYaml(String s) {
    final needsQuote = RegExp(r"[\s:#&*!|>%@\[\]{}'""]|[^\x00-\x7F]")
        .hasMatch(s);
    if (!needsQuote) return s;
    return '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }
}

class _Patch {
  _Patch({required this.start, required this.end, required this.replacement});
  final int start;
  final int end;
  final String replacement;
}
