import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Severity of a logged event.
enum LogLevel { debug, info, warn, error }

class AppLogEntry {
  AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  String format() {
    final ts = timestamp.toIso8601String().substring(11, 23);
    final lvl = level.name.toUpperCase().padRight(5);
    return '[$ts] $lvl ${tag.padRight(10)} $message';
  }
}

/// In-app rotating log buffer used by the connect flow, Mihomo/xray
/// process supervisors, the helper IPC client, and the updater. Surfaced
/// in the Logs page and copyable to clipboard so users can attach the
/// trace to a bug report.
///
/// Singleton — instantiate via [instance] (no DI needed; logs are global).
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const _maxEntries = 1000;

  final _entries = <AppLogEntry>[];
  final _controller = StreamController<AppLogEntry>.broadcast();

  /// All entries currently in the buffer (oldest first).
  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  /// Stream of new entries as they arrive.
  Stream<AppLogEntry> get stream => _controller.stream;

  void debug(String tag, String message) => _add(LogLevel.debug, tag, message);
  void info(String tag, String message) => _add(LogLevel.info, tag, message);
  void warn(String tag, String message) => _add(LogLevel.warn, tag, message);
  void error(String tag, String message) => _add(LogLevel.error, tag, message);

  void _add(LogLevel level, String tag, String message) {
    final e = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.add(e);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    if (!_controller.isClosed) _controller.add(e);
  }

  void clear() {
    _entries.clear();
  }

  /// Build a single text blob suitable for clipboard / file export.
  /// Prepends environment context (OS, app version, locale) so the support
  /// agent doesn't have to ask the user every time.
  Future<String> exportAsText() async {
    final buf = StringBuffer();
    buf.writeln('=== Kiss VPN log ===');
    try {
      final info = await PackageInfo.fromPlatform();
      buf.writeln('App version : ${info.version} (build ${info.buildNumber})');
    } catch (_) {/* dev */}
    buf.writeln('OS          : ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buf.writeln('Locale      : ${Platform.localeName}');
    buf.writeln('Generated   : ${DateTime.now().toIso8601String()}');
    buf.writeln('Entries     : ${_entries.length}');
    buf.writeln('');
    for (final e in _entries) {
      buf.writeln(e.format());
    }
    return buf.toString();
  }

  /// Write the current log to a timestamped file under
  /// `%APPDATA%/com.kissmain/kiss_vpn/logs/` and return its absolute path.
  Future<String> exportAsFile() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'logs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final stamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final path = p.join(dir.path, 'kissvpn-$stamp.log');
    await File(path).writeAsString(await exportAsText());
    return path;
  }
}

/// Riverpod stream — widgets that want live updates watch this; widgets
/// that need a one-shot snapshot read `AppLog.instance.entries` directly.
final appLogStreamProvider = StreamProvider<AppLogEntry>((ref) {
  return AppLog.instance.stream;
});
