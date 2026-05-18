import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';

/// REST + WebSocket client for the Mihomo (Clash.Meta) external controller.
///
/// Mihomo exposes a control plane at http://127.0.0.1:9090 (configurable via
/// `external-controller` in config.yaml). When a `secret` is set we send it as
/// Bearer token.
class MihomoApi {
  MihomoApi({
    this.host = '127.0.0.1',
    this.port = 9090,
    this.secret,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://$host:$port',
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 8),
            headers: secret != null && secret.isNotEmpty
                ? {'Authorization': 'Bearer $secret'}
                : null,
          ),
        );

  final String host;
  final int port;
  final String? secret;
  final Dio _dio;

  // ---------------------------------------------------------------- liveness

  Future<bool> isAlive() async {
    try {
      final r = await _dio.get('/version');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> version() async {
    final r = await _dio.get('/version');
    return r.data is Map ? (r.data['version'] as String?) : null;
  }

  // ----------------------------------------------------------------- proxies

  Future<Map<String, dynamic>> proxies() async {
    final r = await _dio.get('/proxies');
    return Map<String, dynamic>.from(r.data['proxies'] as Map);
  }

  /// Select a proxy inside a Selector group.
  Future<void> selectProxy({required String group, required String name}) {
    final encoded = Uri.encodeComponent(group);
    return _dio.put('/proxies/$encoded', data: {'name': name});
  }

  /// Push the user's pick into **every** Selector group that contains it.
  /// Without this fan-out, `mode: global` keeps routing everything to
  /// GLOBAL → DIRECT (its default), so traffic egresses without going
  /// through the user's chosen proxy.
  ///
  /// Returns the set of groups we actually updated.
  Future<Set<String>> selectProxyEverywhere(String proxyName) async {
    Map<String, dynamic> proxies;
    try {
      proxies = await this.proxies();
    } catch (_) {
      return const {};
    }
    final touched = <String>{};
    for (final entry in proxies.entries) {
      final v = entry.value;
      if (v is! Map) continue;
      final type = (v['type'] as String?)?.toLowerCase();
      if (type != 'selector') continue;
      final members = (v['all'] as List?)?.cast<dynamic>() ?? const [];
      if (!members.contains(proxyName)) continue;
      try {
        await selectProxy(group: entry.key, name: proxyName);
        touched.add(entry.key);
      } catch (_) {/* skip groups that 400 on us */}
    }
    return touched;
  }

  /// Run a latency check against [name] using [testUrl] (HTTP HEAD).
  /// Returns delay in milliseconds, or `null` if unreachable.
  Future<int?> delay({
    required String name,
    String testUrl = 'https://www.gstatic.com/generate_204',
    int timeoutMs = 5000,
  }) async {
    try {
      final r = await _dio.get(
        '/proxies/$name/delay',
        queryParameters: {'url': testUrl, 'timeout': timeoutMs},
      );
      return (r.data['delay'] as num?)?.toInt();
    } on DioException {
      return null;
    }
  }

  // ----------------------------------------------------------------- config

  /// Replace the running config with the YAML at [path]. Pass `force=true`
  /// to also reload providers/rules.
  Future<void> reloadConfig({required String path, bool force = true}) {
    return _dio.put(
      '/configs',
      queryParameters: {if (force) 'force': 'true'},
      data: {'path': path},
    );
  }

  Future<Map<String, dynamic>> getConfigs() async {
    final r = await _dio.get('/configs');
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// Switch routing mode (rule / global / direct).
  Future<void> setMode(String mode) {
    return _dio.patch('/configs', data: {'mode': mode});
  }

  // --------------------------------------------------------------- streams

  /// Live traffic stream — each event is `{up: bytes, down: bytes}` per second.
  Stream<TrafficSample> trafficStream() {
    final ch = _open('/traffic');
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      return TrafficSample(up: (m['up'] as num).toInt(), down: (m['down'] as num).toInt());
    });
  }

  /// Live logs (info/warning/error/debug — set ?level=).
  Stream<LogEntry> logsStream({String level = 'info'}) {
    final ch = _open('/logs?level=$level');
    return ch.stream.map((event) {
      final m = jsonDecode(event as String) as Map<String, dynamic>;
      return LogEntry(level: m['type'] as String, payload: m['payload'] as String);
    });
  }

  IOWebSocketChannel _open(String path) {
    final headers = secret != null && secret!.isNotEmpty
        ? {'Authorization': 'Bearer $secret'}
        : null;
    return IOWebSocketChannel.connect(
      Uri.parse('ws://$host:$port$path'),
      headers: headers,
    );
  }
}

class TrafficSample {
  const TrafficSample({required this.up, required this.down});
  final int up;
  final int down;
}

class LogEntry {
  const LogEntry({required this.level, required this.payload});
  final String level;
  final String payload;
}
