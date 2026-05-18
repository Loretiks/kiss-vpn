import 'dart:async';
import 'dart:io';

/// Plain TCP latency probe — same approach SnowVPN, FlClash and Hiddify use.
///
/// We open a TCP socket to `host:port`, measure the time to the SYN-ACK,
/// then drop the connection. The number is the round-trip from the user's
/// machine to the proxy server's edge — no TLS, no REALITY handshake, no
/// running core required.
///
/// Returns:
///   * `null` — DNS lookup failed (bad hostname).
///   * `-1`   — connect timed out / refused.
///   * `>= 0` — measured millis.
class TcpPing {
  static Future<int?> probe(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (host.isEmpty || port <= 0) return null;

    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final ms = sw.elapsedMilliseconds;
      return ms;
    } on SocketException {
      return -1;
    } on TimeoutException {
      return -1;
    } catch (_) {
      return -1;
    } finally {
      socket?.destroy();
    }
  }

  /// Probe many hosts concurrently. The returned map is keyed by an id
  /// you supply — typically the proxy name — so the caller can render
  /// without joining on host/port pairs.
  static Future<Map<String, int?>> probeMany(
    Map<String, ({String host, int port})> targets, {
    Duration timeout = const Duration(seconds: 4),
    int concurrency = 16,
  }) async {
    final entries = targets.entries.toList();
    final results = <String, int?>{};
    // Run with a soft concurrency cap so we don't fork hundreds of sockets
    // at once on big subscriptions.
    for (var i = 0; i < entries.length; i += concurrency) {
      final batch = entries.skip(i).take(concurrency);
      await Future.wait(batch.map((e) async {
        results[e.key] =
            await probe(e.value.host, e.value.port, timeout: timeout);
      }));
    }
    return results;
  }
}
