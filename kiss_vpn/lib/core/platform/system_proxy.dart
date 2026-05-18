import 'dart:async';
import 'dart:io';

// ignore: unused_import — Socket is used in cleanupIfStale via Socket.connect.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/settings.dart';

/// Toggles the per-user Windows system proxy via the
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
/// registry keys. No admin required — HKCU is writable by the current user.
///
/// When [enabled] is true we point `ProxyServer` at `host:port`, set
/// `ProxyEnable=1`, and add a `ProxyOverride` for local addresses + the
/// VPN provider's own domain (so refreshing the subscription doesn't loop
/// through the tunnel).
///
/// When [enabled] is false we restore the values we backed up under
/// `HKCU\Software\KissVPN\ProxyBackup`. If we have no backup (the user
/// never had a system proxy), we simply set ProxyEnable=0.
class SystemProxy {
  static const _regRoot = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const _backupRoot = r'HKCU\Software\KissVPN\ProxyBackup';
  static const _bypass =
      '<local>;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;kissmain.ru;*.kissmain.ru';

  /// Apply the proxy. Returns true when the registry calls all succeeded.
  static Future<bool> apply({String host = '127.0.0.1', int port = 7890}) async {
    await _backupIfFresh();
    final ok1 = await _reg(['add', _regRoot, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '$host:$port', '/f']);
    final ok2 = await _reg(['add', _regRoot, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f']);
    final ok3 = await _reg(['add', _regRoot, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', _bypass, '/f']);
    await _broadcastSettingsChange();
    return ok1 && ok2 && ok3;
  }

  /// Drop the proxy. Restores prior values if we had any.
  static Future<bool> revert() async {
    final backup = await _readBackup();
    if (backup != null) {
      // Restore explicit prior state.
      await _reg(['add', _regRoot, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', backup.enable, '/f']);
      if (backup.server != null) {
        await _reg(['add', _regRoot, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', backup.server!, '/f']);
      } else {
        await _reg(['delete', _regRoot, '/v', 'ProxyServer', '/f']);
      }
      if (backup.override != null) {
        await _reg(['add', _regRoot, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', backup.override!, '/f']);
      } else {
        await _reg(['delete', _regRoot, '/v', 'ProxyOverride', '/f']);
      }
      await _reg(['delete', _backupRoot, '/f']);
    } else {
      // No backup ever taken — just disable.
      await _reg(['add', _regRoot, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f']);
    }
    await _broadcastSettingsChange();
    return true;
  }

  /// Quick check — `true` when our proxy is currently active.
  static Future<bool> isActive({String host = '127.0.0.1', int port = 7890}) async {
    final enable = await _readValue(_regRoot, 'ProxyEnable');
    if (enable == null) return false;
    if (!enable.contains('0x1')) return false;
    final server = await _readValue(_regRoot, 'ProxyServer');
    return server?.contains('$host:$port') ?? false;
  }

  /// Startup hygiene: if the registry still points at our `127.0.0.1:7890`
  /// proxy but nothing is actually listening there (last session crashed
  /// before disconnect completed), revert. Without this Chrome / Edge keep
  /// trying a dead proxy and show "no internet" until restart.
  static Future<bool> cleanupIfStale(
      {String host = '127.0.0.1', int port = 7890}) async {
    if (!await isActive(host: host, port: port)) return false;
    final listening = await _isListening(host, port);
    if (listening) return false;
    await revert();
    return true;
  }

  static Future<bool> _isListening(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 400));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // --------------------- internals ---------------------------------------

  static Future<void> _backupIfFresh() async {
    // Only back up if the backup key doesn't already exist — otherwise we'd
    // overwrite the user's true prior state with our own injected values on
    // a second Connect.
    final existing = await _readValue(_backupRoot, 'ProxyEnable');
    if (existing != null) return;

    final enable = await _readValue(_regRoot, 'ProxyEnable') ?? '0x0';
    final server = await _readValue(_regRoot, 'ProxyServer');
    final override = await _readValue(_regRoot, 'ProxyOverride');

    await _reg(['add', _backupRoot, '/v', 'ProxyEnable', '/t', 'REG_SZ', '/d', enable.contains('0x1') ? '1' : '0', '/f']);
    if (server != null) {
      await _reg(['add', _backupRoot, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', server, '/f']);
    }
    if (override != null) {
      await _reg(['add', _backupRoot, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', override, '/f']);
    }
  }

  static Future<_ProxyBackup?> _readBackup() async {
    final enable = await _readValue(_backupRoot, 'ProxyEnable');
    if (enable == null) return null;
    return _ProxyBackup(
      enable: enable.contains('1') ? '1' : '0',
      server: await _readValue(_backupRoot, 'ProxyServer'),
      override: await _readValue(_backupRoot, 'ProxyOverride'),
    );
  }

  /// Parses `reg query` output (the value lives after `REG_SZ`/`REG_DWORD`).
  static Future<String?> _readValue(String key, String name) async {
    try {
      final r = await Process.run('reg.exe', ['query', key, '/v', name]);
      if (r.exitCode != 0) return null;
      for (final raw in (r.stdout as String).split('\n')) {
        final line = raw.trim();
        if (!line.startsWith(name)) continue;
        // Format: <name>    <type>    <value...>
        final parts = line.split(RegExp(r'\s{2,}|\t'));
        if (parts.length >= 3) return parts.sublist(2).join(' ').trim();
      }
    } catch (_) {/* ignore */}
    return null;
  }

  static Future<bool> _reg(List<String> args) async {
    try {
      final r = await Process.run('reg.exe', args);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Tell other apps (Chrome, Edge, system services) that proxy settings
  /// changed. Without this, already-running apps keep using the old setup
  /// until restart.
  static Future<void> _broadcastSettingsChange() async {
    // wininet's InternetSetOption(INTERNET_OPTION_SETTINGS_CHANGED) is the
    // canonical signal. Shelling out to `rundll32 wininet,InternetSetOption`
    // is unsupported on modern Windows, but `wininet.dll` listens for the
    // WM_SETTINGCHANGE broadcast that powershell.exe triggers via SendMessage.
    try {
      await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        // Minimal P/Invoke that broadcasts WM_SETTINGCHANGE.
        r'''
Add-Type -Namespace P -Name X -MemberDefinition '[DllImport("user32")] public static extern int SendMessageTimeout(System.IntPtr hWnd,int Msg,System.IntPtr w,string l,int flags,int timeout,out System.IntPtr res);' -ErrorAction SilentlyContinue;
$r = [IntPtr]::Zero;
[P.X]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [IntPtr]0, 'Internet Settings', 0x2, 1000, [ref]$r) | Out-Null
        '''
      ]);
    } catch (_) {/* best-effort */}
  }
}

class _ProxyBackup {
  _ProxyBackup({required this.enable, this.server, this.override});
  final String enable;
  final String? server;
  final String? override;
}

/// Convenience hook for [VpnController]: keep system proxy in sync with the
/// engine choice. Returns true if a proxy change was actually applied.
Future<bool> syncSystemProxy({
  required bool connecting,
  required VpnEngine engine,
}) async {
  // Only Proxy-engine sessions need the registry trick; TUN catches all
  // traffic by itself.
  if (engine != VpnEngine.proxy) return false;
  if (connecting) {
    return SystemProxy.apply();
  } else {
    return SystemProxy.revert();
  }
}

final systemProxyActiveProvider = FutureProvider<bool>((ref) async {
  return SystemProxy.isActive();
});
