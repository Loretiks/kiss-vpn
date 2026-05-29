import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_log.dart';
import 'mihomo_api.dart';

/// Spawns and supervises the Mihomo core process (`KissVPNCore.exe`).
///
/// Phase 1 implementation: runs the core directly from the bundled binary
/// path. In Phase 3 this is replaced by an IPC call to the Helper Service so
/// the core can run elevated (TUN requires admin).
class MihomoProcessManager {
  MihomoProcessManager({this.api});

  final MihomoApi? api;
  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final _logBuffer = <String>[];
  static const _logBufferMax = 30;

  bool get isRunning => _proc != null;

  /// Last lines from Mihomo's stdout/stderr — surfaced to the user when
  /// the core fails to start so they don't get a generic "did not become
  /// ready" timeout with no context.
  List<String> get recentLogs => List.unmodifiable(_logBuffer);

  /// Returns the directory where Mihomo writes/reads its working set:
  /// `%APPDATA%\KissVPN\profile` (config.yaml, cache.db, geodata).
  Future<Directory> profileDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'profile'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Resolve the path to KissVPNCore.exe.
  ///
  /// Search order:
  ///  1. Adjacent to the running app (production layout).
  ///  2. `..\..\..\kiss_vpn_core\bin\KissVPNCore.exe` (dev tree).
  ///  3. `KISSVPN_CORE` environment variable.
  Future<File?> _resolveCore() async {
    final candidates = <String>[
      p.join(p.dirname(Platform.resolvedExecutable), 'KissVPNCore.exe'),
      p.join(p.dirname(Platform.resolvedExecutable), '..', '..', '..', '..',
          'kiss_vpn_core', 'bin', 'KissVPNCore.exe'),
      if (Platform.environment['KISSVPN_CORE'] != null)
        Platform.environment['KISSVPN_CORE']!,
    ];
    for (final c in candidates) {
      final f = File(c);
      if (await f.exists()) return f;
    }
    return null;
  }

  /// Start the core with the config at [configPath]. Throws on failure with
  /// the last lines of Mihomo's own output appended so the user sees the
  /// actual cause (port collision, missing geo file, bad config, etc).
  /// When the caller picked a non-default external-controller port, pass an
  /// [apiForReadiness] bound to that port so the readiness probe doesn't
  /// poll 9090 forever.
  Future<void> start({required String configPath, MihomoApi? apiForReadiness, void Function(String line)? onLog}) async {
    if (_proc != null) return;
    final core = await _resolveCore();
    if (core == null) {
      throw StateError('KissVPNCore.exe not found — bundle it under app dir or set KISSVPN_CORE');
    }
    final profile = await profileDir();

    _logBuffer.clear();
    _proc = await Process.start(
      core.path,
      ['-d', profile.path, '-f', configPath],
      workingDirectory: profile.path,
      mode: ProcessStartMode.normal,
    );

    AppLog.instance.info('mihomo', 'starting: ${core.path} -f $configPath');

    void capture(String line) {
      _logBuffer.add(line);
      if (_logBuffer.length > _logBufferMax) _logBuffer.removeAt(0);
      AppLog.instance.debug('mihomo', line);
      onLog?.call(line);
    }

    _stdoutSub = _proc!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(capture);
    _stderrSub = _proc!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((l) => capture('[stderr] $l'));

    int? exitCode;
    unawaited(_proc!.exitCode.then((code) {
      exitCode = code;
      capture('[core] exited with code $code');
      _proc = null;
    }));

    // Wait for the REST endpoint to come up before returning. Bumped to 20s
    // because cold-start on a slow machine + cache.db migration can take
    // longer than 10s. Bail out immediately if the process exits early —
    // no point waiting the full window for a corpse.
    final ready = await _waitReady(
      const Duration(seconds: 20),
      api: apiForReadiness ?? api ?? MihomoApi(),
      hasExited: () => exitCode != null,
    );
    if (!ready) {
      final tail = _logBuffer.isEmpty
          ? '(no output)'
          : _logBuffer.reversed.take(8).toList().reversed.join('\n  ');
      final cause = exitCode != null
          ? 'Mihomo exited prematurely (code $exitCode).'
          : 'Mihomo did not become ready within 20s.';
      await stop();
      throw StateError(
        '$cause\n\n'
        'Возможные причины: порт 9090 или 7890 занят другим VPN-клиентом '
        '(SnowVPN, Clash for Windows, v2rayN), отсутствуют geo-файлы, '
        'или антивирус блокирует процесс.\n\n'
        'Последние строки из ядра:\n  $tail',
      );
    }
  }

  Future<bool> _waitReady(
    Duration timeout, {
    required MihomoApi api,
    required bool Function() hasExited,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (hasExited()) return false;
      if (await api.isAlive()) return true;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  Future<void> stop() async {
    final proc = _proc;
    if (proc == null) return;
    proc.kill(ProcessSignal.sigterm);
    try {
      await proc.exitCode.timeout(const Duration(seconds: 5));
    } catch (_) {
      proc.kill(ProcessSignal.sigkill);
    }
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _proc = null;
  }
}
