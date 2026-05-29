import 'dart:io';

/// Probes localhost TCP ports for availability. Used at connect time to pick
/// non-conflicting ports for Mihomo's `external-controller` (9090 default)
/// and `mixed-port` (7890 default) when another VPN client (SnowVPN, Clash
/// for Windows, v2rayN, etc.) is already holding them.
class PortFinder {
  /// Tries each port in [preferred] in order; returns the first one that's
  /// free. Falls back to an OS-assigned ephemeral port if nothing in the list
  /// is available.
  static Future<int> findFree(List<int> preferred) async {
    for (final port in preferred) {
      if (await isFree(port)) return port;
    }
    final s = await ServerSocket.bind('127.0.0.1', 0);
    final port = s.port;
    await s.close();
    return port;
  }

  /// Binds momentarily to [port] and releases it — `true` means we'll be
  /// able to bind it again immediately (modulo race), `false` means someone
  /// else has it.
  static Future<bool> isFree(int port) async {
    try {
      final s = await ServerSocket.bind('127.0.0.1', port, shared: false);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
