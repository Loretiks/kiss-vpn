import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../logging/app_log.dart';

/// Supervises a single bundled `xray.exe` instance.
///
/// xray runs as an unprivileged sidecar to Mihomo: it accepts socks5 on
/// localhost and forwards to vless+grpc servers. Lifecycle is managed by
/// [GrpcBridge] and tied to the same connect/disconnect transitions as
/// the main core.
class XrayProcess {
  Process? _proc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  bool get isRunning => _proc != null;

  /// Search order matches `MihomoProcessManager._resolveCore` for symmetry.
  static Future<File?> resolveBinary() async {
    final candidates = <String>[
      p.join(p.dirname(Platform.resolvedExecutable), 'xray.exe'),
      p.join(p.dirname(Platform.resolvedExecutable), '..', '..', '..', '..',
          'kiss_vpn_core', 'bin', 'xray.exe'),
      if (Platform.environment['KISSVPN_XRAY'] != null)
        Platform.environment['KISSVPN_XRAY']!,
    ];
    for (final c in candidates) {
      final f = File(c);
      if (await f.exists()) return f;
    }
    return null;
  }

  Future<void> start({
    required String configPath,
    void Function(String line)? onLog,
  }) async {
    if (_proc != null) return;
    final bin = await resolveBinary();
    if (bin == null) {
      throw StateError(
          'xray.exe not found — bundled binary missing from app dir');
    }

    // xray resolves its own -config argument relative to its working
    // directory; passing absolute paths sidesteps any ambiguity.
    final absConfig = p.normalize(p.absolute(configPath));
    _proc = await Process.start(
      bin.path,
      ['run', '-config', absConfig],
      workingDirectory: p.dirname(absConfig),
      mode: ProcessStartMode.normal,
    );

    AppLog.instance.info('xray', 'starting: ${bin.path} -config $absConfig');

    _stdoutSub = _proc!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((l) {
      AppLog.instance.debug('xray', l);
      onLog?.call('[xray] $l');
    });
    _stderrSub = _proc!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((l) {
      AppLog.instance.warn('xray', l);
      onLog?.call('[xray-err] $l');
    });

    unawaited(_proc!.exitCode.then((code) {
      AppLog.instance.info('xray', 'exited with code $code');
      onLog?.call('[xray] exited with code $code');
      _proc = null;
    }));

    // Brief grace window for xray to bind its sockets before Mihomo starts
    // dialing into them. xray binds synchronously on startup so 300ms is
    // generous; we don't poll a control plane because xray's stats API is
    // off by default and we don't need it.
    await Future.delayed(const Duration(milliseconds: 300));
    if (_proc == null) {
      throw StateError('xray exited immediately — check the log');
    }
  }

  Future<void> stop() async {
    final proc = _proc;
    if (proc == null) return;
    proc.kill(ProcessSignal.sigterm);
    try {
      await proc.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      proc.kill(ProcessSignal.sigkill);
    }
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _proc = null;
  }
}
