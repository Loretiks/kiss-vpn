import 'dart:io';
import 'dart:math';

import '../storage/secrets_store.dart';

/// Identity headers the kissmain.ru panel expects to recognise a client and
/// list it under "Мои устройства" — Happ, Remnawave-Mobile and v2RayTun all
/// send the same four `x-*` headers when hitting `/sub`:
///
///   x-hwid          stable per-install UUID v4
///   x-device-os     Windows | macOS | Linux | iOS | Android
///   x-ver-os        OS version (e.g. "10.0.26200")
///   x-device-model  user-readable model name (hostname on desktop)
///
/// The HWID is generated once on first run and persisted to [SecretsStore].
/// Reinstalling regenerates it — same behaviour as the mobile clients when
/// the user wipes app data.
class DeviceIdentity {
  DeviceIdentity._({
    required this.hwid,
    required this.deviceOs,
    required this.verOs,
    required this.deviceModel,
  });

  final String hwid;
  final String deviceOs;
  final String verOs;
  final String deviceModel;

  static const _kHwid = 'kiss.device.hwid';

  static Future<DeviceIdentity> loadOrCreate(SecretsStore store) async {
    var hwid = await store.read(_kHwid);
    if (hwid == null || hwid.isEmpty) {
      hwid = _generateUuidV4();
      await store.write(_kHwid, hwid);
    }
    return DeviceIdentity._(
      hwid: hwid,
      deviceOs: _detectOs(),
      verOs: _detectOsVersion(),
      deviceModel: _detectModel(),
    );
  }

  Map<String, String> toHeaders() => {
        'x-hwid': hwid,
        'x-device-os': deviceOs,
        'x-ver-os': verOs,
        'x-device-model': deviceModel,
      };

  // ---- detection helpers -----------------------------------------------

  static String _detectOs() {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// On Windows `Platform.operatingSystemVersion` looks like
  /// `"Windows 11 Pro" 10.0 (Build 26200)` or `"Microsoft Windows" 10.0.26200`.
  /// We extract `major.minor.build` and rewrite `10.0.<>=22000>` as `11.x.x`
  /// so the panel displays it the way users actually call their OS.
  static String _detectOsVersion() {
    final raw = Platform.operatingSystemVersion;
    final m = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(raw);
    if (m == null) return raw;
    final major = int.parse(m.group(1)!);
    final minor = int.parse(m.group(2)!);
    final build = int.tryParse(m.group(3) ?? '0') ?? 0;
    if (Platform.isWindows && major == 10 && build >= 22000) {
      return '11.0.$build';
    }
    return build == 0 ? '$major.$minor' : '$major.$minor.$build';
  }

  static String _detectModel() {
    try {
      final h = Platform.localHostname.trim();
      if (h.isNotEmpty) return h;
    } catch (_) {/* sandboxed / no hostname access */}
    return _detectOs();
  }

  static String _generateUuidV4() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final s = b.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-'
        '${s.substring(16, 20)}-${s.substring(20)}';
  }
}
