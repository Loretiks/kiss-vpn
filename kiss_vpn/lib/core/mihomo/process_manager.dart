import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  bool get isRunning => _proc != null;

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

  /// Start the core with the config at [configPath]. Throws on failure.
  Future<void> start({required String configPath, void Function(String line)? onLog}) async {
    if (_proc != null) return;
    final core = await _resolveCore();
    if (core == null) {
      throw StateError('KissVPNCore.exe not found — bundle it under app dir or set KISSVPN_CORE');
    }
    final profile = await profileDir();

    _proc = await Process.start(
      core.path,
      ['-d', profile.path, '-f', configPath],
      workingDirectory: profile.path,
      mode: ProcessStartMode.normal,
    );

    _stdoutSub = _proc!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((l) => onLog?.call(l));
    _stderrSub = _proc!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((l) => onLog?.call('[stderr] $l'));

    unawaited(_proc!.exitCode.then((code) {
      onLog?.call('[core] exited with code $code');
      _proc = null;
    }));

    // Wait for the REST endpoint to come up before returning.
    final ready = await _waitReady(const Duration(seconds: 10));
    if (!ready) {
      await stop();
      throw StateError('Mihomo did not become ready within 10s');
    }
  }

  Future<bool> _waitReady(Duration timeout) async {
    final api = this.api ?? MihomoApi();
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
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
