import 'dart:convert';

/// Single grpc-proxy outbound that xray should expose via a local socks5
/// inbound. The orchestrator (`GrpcBridge`) builds these from the grpc entries
/// it finds in the panel's Clash YAML.
class XrayOutbound {
  const XrayOutbound({
    required this.tag,
    required this.localPort,
    required this.address,
    required this.port,
    required this.uuid,
    required this.serviceName,
    this.security,            // 'tls' | 'reality' | null
    this.serverName,
    this.fingerprint,
    this.realityPublicKey,
    this.realityShortId,
    this.realitySpiderX,
    this.alpn,
    this.flow,
  });

  final String tag;
  final int localPort;
  final String address;
  final int port;
  final String uuid;
  final String serviceName;
  final String? security;
  final String? serverName;
  final String? fingerprint;
  final String? realityPublicKey;
  final String? realityShortId;
  final String? realitySpiderX;
  final String? alpn;
  final String? flow;
}

/// Builds a self-contained xray-core config that fronts a set of vless+grpc
/// servers with local socks5 inbounds — one inbound + outbound pair per
/// proxy, wired together by an explicit routing rule.
///
/// The crucial bit vs. Mihomo: `grpcSettings.multiMode = true`. xray's gRPC
/// client opens a real bidirectional stream when this is set, which is what
/// stops the server-side "rpc error: code = Canceled" failures Mihomo
/// triggers because its gRPC transport is unary-only.
String buildXrayConfig(List<XrayOutbound> outs) {
  final inbounds = <Map<String, dynamic>>[];
  final outbounds = <Map<String, dynamic>>[];
  final rules = <Map<String, dynamic>>[];

  for (final o in outs) {
    inbounds.add({
      'tag': 'in-${o.tag}',
      'protocol': 'socks',
      'listen': '127.0.0.1',
      'port': o.localPort,
      'settings': {
        'auth': 'noauth',
        'udp': true,
      },
      'sniffing': {
        'enabled': true,
        'destOverride': ['http', 'tls'],
      },
    });

    final streamSettings = <String, dynamic>{
      'network': 'grpc',
      'grpcSettings': {
        'serviceName': o.serviceName,
        // multiMode = true → bidirectional streaming gRPC. This is the
        // whole reason we're bypassing Mihomo for grpc proxies.
        'multiMode': true,
        'idle_timeout': 60,
        'health_check_timeout': 20,
        'permit_without_stream': false,
      },
    };

    if (o.security == 'reality') {
      streamSettings['security'] = 'reality';
      streamSettings['realitySettings'] = {
        if (o.serverName != null) 'serverName': o.serverName,
        if (o.fingerprint != null) 'fingerprint': o.fingerprint else 'fingerprint': 'chrome',
        if (o.realityPublicKey != null) 'publicKey': o.realityPublicKey,
        if (o.realityShortId != null) 'shortId': o.realityShortId,
        if (o.realitySpiderX != null) 'spiderX': o.realitySpiderX,
      };
    } else if (o.security == 'tls') {
      streamSettings['security'] = 'tls';
      streamSettings['tlsSettings'] = {
        if (o.serverName != null) 'serverName': o.serverName,
        if (o.fingerprint != null) 'fingerprint': o.fingerprint else 'fingerprint': 'chrome',
        if (o.alpn != null) 'alpn': o.alpn!.split(','),
        'allowInsecure': false,
      };
    }

    outbounds.add({
      'tag': 'out-${o.tag}',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': o.address,
            'port': o.port,
            'users': [
              {
                'id': o.uuid,
                'encryption': 'none',
                if (o.flow != null && o.flow!.isNotEmpty) 'flow': o.flow,
              },
            ],
          },
        ],
      },
      'streamSettings': streamSettings,
    });

    rules.add({
      'type': 'field',
      'inboundTag': ['in-${o.tag}'],
      'outboundTag': 'out-${o.tag}',
    });
  }

  // Catch-all blackhole — if a packet somehow misses the per-inbound rule
  // we'd rather drop it than leak it via xray's freedom default.
  outbounds.add({'tag': 'block', 'protocol': 'blackhole'});
  rules.add({'type': 'field', 'outboundTag': 'block', 'network': 'tcp,udp'});

  final config = <String, dynamic>{
    'log': {'loglevel': 'warning'},
    'inbounds': inbounds,
    'outbounds': outbounds,
    'routing': {
      'domainStrategy': 'AsIs',
      'rules': rules,
    },
  };

  return const JsonEncoder.withIndent('  ').convert(config);
}
