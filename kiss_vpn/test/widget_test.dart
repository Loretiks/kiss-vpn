// Placeholder test — proper unit and widget coverage lands in Phase 4.
import 'package:flutter_test/flutter_test.dart';

import 'package:kiss_vpn/core/subscription/vless_parser.dart';

void main() {
  test('parses a kissmain vless+reality link', () {
    const url =
        'vless://6e7ac464-5920-468e-9125-a5c76b36ba5c@2.26.122.129:1443'
        '?encryption=none&flow=xtls-rprx-vision&type=tcp&headerType=none'
        '&security=reality&sni=id.vk.ru&fp=chrome'
        '&pbk=HPiDftmYjFeFeUNgc73DsGFzBms_g3JKGstb3XiVHJ2s'
        '&sid=d6f8aabe76399551#Finland';

    final p = VlessParser.parseOne(url);
    expect(p, isNotNull);
    expect(p!.uuid, '6e7ac464-5920-468e-9125-a5c76b36ba5c');
    expect(p.server, '2.26.122.129');
    expect(p.port, 1443);
    expect(p.flow, 'xtls-rprx-vision');
    expect(p.security, 'reality');
    expect(p.sni, 'id.vk.ru');
    expect(p.realityPublicKey,
        'HPiDftmYjFeFeUNgc73DsGFzBms_g3JKGstb3XiVHJ2s');
    expect(p.realityShortId, 'd6f8aabe76399551');
    expect(p.name, 'Finland');
  });
}
