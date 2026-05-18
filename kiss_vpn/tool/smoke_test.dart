// Standalone smoke test for subscription → Mihomo pipeline.
// Run:
//   $env:KISSVPN_CORE = "E:\vpn\kiss_vpn_core\bin\KissVPNCore.exe"
//   dart run tool/smoke_test.dart <subscription-url>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:kiss_vpn/core/mihomo/config_writer.dart';
import 'package:kiss_vpn/core/mihomo/mihomo_api.dart';
import 'package:kiss_vpn/core/subscription/sub_fetcher.dart';
import 'package:kiss_vpn/core/subscription/vless_parser.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/smoke_test.dart <subscription-url>');
    exit(64);
  }
  final url = args.first;
  final corePath = Platform.environment['KISSVPN_CORE'];
  if (corePath == null || !await File(corePath).exists()) {
    stderr.writeln('Set KISSVPN_CORE to the absolute path of KissVPNCore.exe');
    exit(64);
  }

  stdout.writeln('1) fetching subscription…');
  final resp = await SubFetcher().fetch(url);
  final body = resp.body.trim();
  stdout.writeln('   ${body.length} bytes, userinfo=${resp.userInfo != null}');

  final tmp = await Directory.systemTemp.createTemp('kiss_vpn_smoke_');
  final configPath = p.join(tmp.path, 'config.yaml');

  final looksClash = body.startsWith('mixed-port:') ||
      body.startsWith('port:') ||
      body.startsWith('proxies:');

  if (looksClash) {
    stdout.writeln('2) detected Clash YAML — saving as-is');
    await File(configPath).writeAsString(body);
    final doc = loadYaml(body);
    final proxies = (doc is YamlMap ? doc['proxies'] as YamlList? : null);
    stdout.writeln('   ${proxies?.length ?? 0} proxies in YAML');
  } else {
    final list = VlessParser.parseSubscription(body);
    stdout.writeln('2) parsed ${list.length} vless proxies — building YAML');
    if (list.isEmpty) {
      stderr.writeln('   no proxies — aborting');
      exit(2);
    }
    await ConfigWriter.writeConfig(
        path: configPath, proxies: list, tun: false);
  }

  // Stage geo files alongside config (Mihomo reads them from -d dir).
  final geoDir = Directory(p.join(File(corePath).parent.parent.path, 'geo'));
  if (await geoDir.exists()) {
    for (final fn in ['geoip.dat', 'geosite.dat', 'geoip.metadb']) {
      final src = File(p.join(geoDir.path, fn));
      if (await src.exists()) await src.copy(p.join(tmp.path, fn));
    }
  }

  stdout.writeln('3) starting Mihomo…');
  final proc = await Process.start(
    corePath,
    ['-d', tmp.path, '-f', configPath],
    workingDirectory: tmp.path,
  );
  proc.stdout
      .transform(systemEncoding.decoder)
      .transform(const LineSplitter())
      .listen((l) => stdout.writeln('   [core] $l'));
  proc.stderr
      .transform(systemEncoding.decoder)
      .transform(const LineSplitter())
      .listen((l) => stderr.writeln('   [core stderr] $l'));

  final api = MihomoApi();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await api.isAlive()) break;
    await Future.delayed(const Duration(milliseconds: 200));
  }
  final v = await api.version();
  stdout.writeln('   Mihomo version: $v');

  // Switch the running config to rule-based dispatch so MATCH rules (and the
  // panel-curated group selector) take effect. Pure `global` mode routes
  // everything through a built-in GLOBAL group whose default is DIRECT.
  await api.setMode('rule');
  stdout.writeln('   mode=rule');

  stdout.writeln('4) checking egress through 127.0.0.1:7890…');

  Future<void> probe(String label, String proxySpec, String testUrl) async {
    final cli = HttpClient();
    cli.findProxy = (_) => proxySpec;
    cli.connectionTimeout = const Duration(seconds: 15);
    try {
      final r = await cli.getUrl(Uri.parse(testUrl));
      final resp = await r.close();
      final body = await resp.transform(systemEncoding.decoder).join();
      stdout.writeln('   $label: ${body.trim()}');
    } catch (e) {
      stdout.writeln('   $label probe failed: $e');
    } finally {
      cli.close(force: true);
    }
  }

  // Use ipv4-only endpoints to avoid Happy-Eyeballs IPv6-first dialing the
  // proxied server can't reach.
  await probe('DIRECT', 'DIRECT', 'https://api.ipify.org');
  await probe('PROXY ', 'PROXY 127.0.0.1:7890', 'https://api.ipify.org');
  await probe('PROXY ', 'PROXY 127.0.0.1:7890', 'http://ip.sb');

  stdout.writeln('5) stopping Mihomo…');
  proc.kill(ProcessSignal.sigterm);
  try {
    await proc.exitCode.timeout(const Duration(seconds: 5));
  } catch (_) {
    proc.kill(ProcessSignal.sigkill);
  }
  await Future.delayed(const Duration(milliseconds: 300));
  try {
    await tmp.delete(recursive: true);
  } catch (_) {}
  stdout.writeln('done.');
}
