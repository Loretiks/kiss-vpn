import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_identity.dart';

/// Downloads a raw subscription body.
///
/// User-Agent shape: `KissVPN/<version> (Windows NT 10.0; Win64; <arch>; clash)`.
///
/// Notes on this exact format:
///  * The first token is `KissVPN/<version>` — `user_agents`-style libs that
///    most subscription panels (Marzban / v2board / 3x-ui) use will pull it
///    as the browser family + version, so device notifications read as
///    "Model: KissVPN · Platform: Windows · App: KissVPN x.y.z" instead of
///    leaking "clash.meta 1.19".
///  * The parenthesized block follows the Mozilla/Chrome convention so OS
///    detection cleanly resolves to "Windows".
///  * The bare word `clash` is appended inside the parens *without* a
///    `/version` suffix. Format-detection in those panels is a plain
///    substring check (`"clash" in ua`), which still matches, so we keep
///    receiving the rich Clash YAML — but `user_agents` regex won't see it
///    as a known `Name/Version` token and won't overwrite the family.
///  * If a server still falls back to a base64 vless list, the repository
///    rebuilds a Clash config locally via [ConfigWriter] — nothing breaks.
class SubFetcher {
  SubFetcher({Dio? dio, DeviceIdentity? identity})
      : _dio = dio ?? Dio(),
        _identity = identity;

  final Dio _dio;
  final DeviceIdentity? _identity;
  String? _cachedUa;

  Future<String> _userAgent() async {
    if (_cachedUa != null) return _cachedUa!;
    String appVersion = '0.1.0';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* dev / test — fall back to constant */}
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'x64';
    return _cachedUa =
        'KissVPN/$appVersion (Windows NT 10.0; Win64; $arch; clash)';
  }

  Future<SubResponse> fetch(String url) async {
    final ua = await _userAgent();
    final headers = <String, String>{
      'User-Agent': ua,
      'Accept': '*/*',
    };
    // HWID-protocol headers — kissmain.ru / Remnawave panels read these to
    // identify and list the device. Without them the client shows up as
    // "unknown app". Optional in tests where identity isn't wired up.
    final identity = _identity;
    if (identity != null) {
      headers.addAll(identity.toHeaders());
    }
    final r = await _dio.get<String>(
      url,
      options: Options(
        headers: headers,
        followRedirects: true,
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw StateError('Subscription endpoint returned ${r.statusCode}');
    }

    final respHeaders = r.headers.map.map((k, v) => MapEntry(k.toLowerCase(), v.join('; ')));
    return SubResponse(
      body: r.data ?? '',
      userInfo: respHeaders['subscription-userinfo'],
      profileTitle: respHeaders['profile-title'] ?? respHeaders['content-disposition'],
      profileUpdateInterval: int.tryParse(respHeaders['profile-update-interval'] ?? ''),
    );
  }
}

class SubResponse {
  const SubResponse({
    required this.body,
    this.userInfo,
    this.profileTitle,
    this.profileUpdateInterval,
  });
  final String body;
  /// Raw RFC-style header from the sub provider, e.g.
  /// `upload=0; download=12345; total=107374182400; expire=1893456000`.
  final String? userInfo;
  final String? profileTitle;
  final int? profileUpdateInterval;

  SubInfo? get info {
    if (userInfo == null) return null;
    final m = <String, int>{};
    for (final part in userInfo!.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length == 2) {
        m[kv[0].trim()] = int.tryParse(kv[1].trim()) ?? 0;
      }
    }
    return SubInfo(
      upload: m['upload'] ?? 0,
      download: m['download'] ?? 0,
      total: m['total'] ?? 0,
      expire: m['expire'] == null || m['expire'] == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['expire']! * 1000),
    );
  }
}

class SubInfo {
  const SubInfo({
    required this.upload,
    required this.download,
    required this.total,
    this.expire,
  });
  final int upload;
  final int download;
  final int total;
  final DateTime? expire;

  int get used => upload + download;
  int get remaining => total == 0 ? 0 : total - used;
}
