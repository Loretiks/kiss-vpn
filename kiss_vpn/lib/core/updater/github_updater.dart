import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Single release surfaced from the GitHub Releases API that's newer than
/// the running build and has a matching installer asset attached.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.installerUrl,
    required this.installerSize,
    required this.releaseUrl,
    required this.publishedAt,
    required this.notes,
  });

  /// Tag name with any leading `v` stripped — `0.1.1`.
  final String version;
  final String installerUrl;
  final int installerSize;
  final String releaseUrl;
  final DateTime publishedAt;
  final String notes;
}

/// Polls GitHub Releases for a newer build, downloads the installer to the
/// user's temp directory and launches Inno Setup in silent restart-app mode.
///
/// We deliberately don't use the `update_engine` package — it pulls in
/// Android-specific dependencies and assumes a non-installer update flow.
class GithubUpdater {
  GithubUpdater({this.owner = 'Loretiks', this.repo = 'kiss-vpn'});

  final String owner;
  final String repo;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        // Asking for the v3 envelope lets us depend on `tag_name`,
        // `assets[].browser_download_url`, `published_at` being present.
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'kiss-vpn-updater',
      },
    ),
  );

  String get _apiLatest =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// Compares two semver-ish strings (`0.1.1` vs `0.1.0`). Anything that
  /// doesn't parse as ints in each segment is treated as less than the
  /// other side so we never claim a malformed version is newer.
  static int compareVersions(String a, String b) {
    final ap = a.split('.').map(int.tryParse).toList();
    final bp = b.split('.').map(int.tryParse).toList();
    final n = ap.length > bp.length ? ap.length : bp.length;
    for (var i = 0; i < n; i++) {
      final av = (i < ap.length ? ap[i] : 0) ?? -1;
      final bv = (i < bp.length ? bp[i] : 0) ?? -1;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  /// Returns the running build's version string (`0.1.0`).
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Hits GitHub for the latest release. Returns null when:
  ///   * the network call fails (offline, rate-limited, repo missing)
  ///   * the release isn't newer than the running build
  ///   * the release doesn't have a `KissVPN-Setup-*.exe` asset
  Future<UpdateInfo?> check() async {
    Response<dynamic> r;
    try {
      r = await _dio.get<dynamic>(_apiLatest);
    } catch (_) {
      return null;
    }
    if (r.statusCode != 200 || r.data is! Map) return null;

    final data = Map<String, dynamic>.from(r.data as Map);
    final tagRaw = (data['tag_name'] as String?)?.trim() ?? '';
    if (tagRaw.isEmpty) return null;
    final tag = tagRaw.replaceFirst(RegExp(r'^v', caseSensitive: false), '');

    final current = await currentVersion();
    if (compareVersions(tag, current) <= 0) return null;

    final assets = (data['assets'] as List?) ?? const [];
    Map<String, dynamic>? installer;
    for (final a in assets) {
      if (a is! Map) continue;
      final name = (a['name'] as String?) ?? '';
      if (name.toLowerCase().startsWith('kissvpn-setup-') &&
          name.toLowerCase().endsWith('.exe')) {
        installer = Map<String, dynamic>.from(a);
        break;
      }
    }
    if (installer == null) return null;

    return UpdateInfo(
      version: tag,
      installerUrl: installer['browser_download_url'] as String,
      installerSize: (installer['size'] as num?)?.toInt() ?? 0,
      releaseUrl: (data['html_url'] as String?) ?? '',
      publishedAt: DateTime.tryParse(data['published_at'] as String? ?? '') ??
          DateTime.now(),
      notes: (data['body'] as String?) ?? '',
    );
  }

  /// Downloads the installer into the user's temp dir. [onProgress] is
  /// called with (received, total) byte counts — total may be -1 if the
  /// server didn't send Content-Length.
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final tmp = await getTemporaryDirectory();
    final target = File(p.join(tmp.path, 'KissVPN-Setup-${info.version}.exe'));
    // Re-download even if the file exists — we don't verify checksums yet,
    // so a partial file from a previous failure shouldn't be trusted.
    if (await target.exists()) await target.delete();
    await _dio.download(
      info.installerUrl,
      target.path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );
    return target;
  }

  /// Launches the freshly-downloaded installer and exits the current
  /// process so Inno Setup can overwrite our files.
  ///
  /// Flags used:
  ///   * `/SILENT` — show progress, no prompts. We deliberately avoid
  ///     `/VERYSILENT` so the user sees that *something* is happening.
  ///   * `/SUPPRESSMSGBOXES` — auto-confirm overwrite of in-use files.
  ///   * `/CLOSEAPPLICATIONS` — installer asks us to close before copying.
  ///   * `/RESTARTAPPLICATIONS` — start the app back up after install.
  ///   * `/NORESTART` — don't reboot the machine for a service refresh.
  Future<void> installAndExit(File installer) async {
    await Process.start(
      installer.path,
      [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
        '/NORESTART',
      ],
      mode: ProcessStartMode.detached,
    );
    // Give Inno Setup a beat to settle before we exit — without this the
    // brand-new installer process can race against our death and bail.
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }
}
