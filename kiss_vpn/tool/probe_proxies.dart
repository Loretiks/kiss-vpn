// Probe each VLESS proxy in the running Mihomo for latency + actual egress.
// Assumes KissVPNCore.exe is already running with the kissmain.ru config.
//
// Run while Mihomo is up:
//   dart run tool/probe_proxies.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final base = Uri.parse('http://127.0.0.1:9090');
  final cli = HttpClient();

  Future<Map<String, dynamic>> getJson(String path) async {
    final req = await cli.getUrl(base.resolve(path));
    final res = await req.close();
    final s = await res.transform(utf8.decoder).join();
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<int> put(String path, Map<String, dynamic> body) async {
    final req = await cli.putUrl(base.resolve(path));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close();
    await res.drain();
    return res.statusCode;
  }

  // 1) Switch mode to rule so MATCH → Remnawave is the path.
  final patchReq = await cli.patchUrl(base.resolve('/configs'));
  patchReq.headers.contentType = ContentType.json;
  patchReq.write(jsonEncode({'mode': 'rule'}));
  await (await patchReq.close()).drain();
  stdout.writeln('mode=rule');

  // 2) List all vless proxies.
  final proxies = (await getJson('/proxies'))['proxies'] as Map<String, dynamic>;
  final vlessNames = proxies.entries
      .where((e) {
        final v = e.value as Map<String, dynamic>;
        return (v['type'] as String?)?.toLowerCase() == 'vless';
      })
      .map((e) => e.key)
      .toList();

  stdout.writeln('found ${vlessNames.length} vless proxies');

  // 3) Find the panel-curated proxy-group that contains them. Skip the
  // built-in GLOBAL/PROXY (those are reserved names Mihomo creates regardless
  // of the user's config). The first user-defined selector wins.
  const reserved = {'GLOBAL', 'DIRECT', 'REJECT', 'PROXY'};
  final groupName = proxies.entries.firstWhere((e) {
    if (reserved.contains(e.key)) return false;
    final v = e.value as Map<String, dynamic>;
    return (v['type'] as String?)?.toLowerCase() == 'selector' &&
        v['all'] is List &&
        (v['all'] as List).any((p) => vlessNames.contains(p));
  }, orElse: () => MapEntry('', <String, dynamic>{})).key;
  stdout.writeln('group: "$groupName"');

  // 4) For each proxy: switch group selection, probe delay, probe egress IP.
  for (final name in vlessNames) {
    final delay = await cli
        .getUrl(base.resolve(
            '/proxies/${Uri.encodeComponent(name)}/delay?url=https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204&timeout=5000'))
        .then((r) => r.close())
        .then((res) async {
      final s = await res.transform(utf8.decoder).join();
      return s;
    });

    if (groupName.isNotEmpty) {
      final st = await put('/proxies/${Uri.encodeComponent(groupName)}', {'name': name});
      stdout.writeln('  switch -> $name  PUT=$st');
    }
    await Future.delayed(const Duration(milliseconds: 400));

    // egress probe via HTTP proxy
    final pcli = HttpClient();
    pcli.findProxy = (_) => 'PROXY 127.0.0.1:7890';
    pcli.connectionTimeout = const Duration(seconds: 15);
    String egress;
    try {
      final r = await pcli.getUrl(
          Uri.parse('http://ip-api.com/json/?fields=query,country,isp'));
      final res = await r.close();
      egress = await res.transform(utf8.decoder).join();
    } catch (e) {
      egress = 'ERR: $e';
    } finally {
      pcli.close(force: true);
    }
    pcli.close(force: true);

    stdout.writeln('  $name');
    stdout.writeln('    delay  : $delay');
    stdout.writeln('    egress : $egress');
  }

  cli.close(force: true);
}
