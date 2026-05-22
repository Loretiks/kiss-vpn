// ignore_for_file: avoid_print

import 'dart:io';

import 'package:kiss_vpn/core/xray/grpc_bridge.dart';
import 'package:kiss_vpn/core/xray/xray_config.dart';
import 'package:yaml/yaml.dart';

/// Hand-run sanity script — not wired into `flutter test`. Produces a
/// sample xray config and the rewritten Mihomo YAML you can inspect:
///
///   $env:KISSVPN_XRAY = "...\xray.exe"
///   dart run test/xray_sanity.dart
///
/// Verifies (a) xray accepts the JSON we emit, (b) GrpcBridge rewrites
/// grpc proxies to socks5 stubs while leaving non-grpc entries untouched.
Future<void> main() async {
  final outs = [
    const XrayOutbound(
      tag: 'de3_0',
      localPort: 12000,
      address: 'de3.example.com',
      port: 443,
      uuid: '00000000-0000-4000-8000-000000000001',
      serviceName: 'foo-svc',
      security: 'reality',
      serverName: 'sni.example.com',
      fingerprint: 'chrome',
      realityPublicKey: '66owMq9_-VnjF2oWrUeBlVj2E4wNz3iUrj9pSDstR2Y',
      realityShortId: '0123',
      flow: 'xtls-rprx-vision',
    ),
  ];

  final outDir = Directory('build/xray-sanity').absolute;
  if (!await outDir.exists()) await outDir.create(recursive: true);

  await File('${outDir.path}/config.json')
      .writeAsString(buildXrayConfig(outs));

  const sampleYaml = '''
mixed-port: 7890
mode: rule

proxies:
  - name: "DE-3 grpc"
    type: vless
    server: de3.example.com
    port: 443
    uuid: 00000000-0000-4000-8000-000000000001
    network: grpc
    grpc-opts:
      grpc-service-name: foo-svc
    tls: true
    servername: sni.example.com
    client-fingerprint: chrome
    reality-opts:
      public-key: 66owMq9_-VnjF2oWrUeBlVj2E4wNz3iUrj9pSDstR2Y
      short-id: "0123"
    flow: xtls-rprx-vision
  - name: "NL-1 tcp"
    type: vless
    server: nl1.example.com
    port: 443
    uuid: deadbeef-0000-4000-8000-000000000003
    network: tcp
    tls: true

rules:
  - MATCH,Proxy
''';
  final bridge = GrpcBridge();
  final rewritten =
      await bridge.setup(sampleYaml, workDir: outDir.path);
  await File('${outDir.path}/rewritten.yaml').writeAsString(rewritten);
  await bridge.teardown();

  // Sanity: result must still parse and the grpc proxy must now be socks5.
  final parsed = loadYaml(rewritten) as YamlMap;
  final proxies = parsed['proxies'] as YamlList;
  final de3 = proxies.firstWhere((e) => e['name'] == 'DE-3 grpc') as YamlMap;
  if (de3['type'] != 'socks5' || de3['port'] != 12000) {
    stderr.writeln('FAIL: DE-3 not rewritten correctly → $de3');
    exit(1);
  }
  final nl1 = proxies.firstWhere((e) => e['name'] == 'NL-1 tcp') as YamlMap;
  if (nl1['type'] != 'vless') {
    stderr.writeln('FAIL: NL-1 should be untouched → $nl1');
    exit(1);
  }
  print('OK · xray config + rewritten yaml at ${outDir.path}');
  exit(0);
}
