import 'dart:convert';

import 'vless_proxy.dart';

/// Parses VLESS share-links (`vless://uuid@host:port?params#name`) into
/// [VlessProxy]. Tolerates malformed entries by returning null instead of
/// throwing — callers should filter nulls out of a subscription stream.
class VlessParser {
  /// Parse a single line. Returns null if the line is not a valid vless URL.
  static VlessProxy? parseOne(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('vless://')) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.userInfo.isEmpty || uri.host.isEmpty || uri.port == 0) {
        return null;
      }

      final params = uri.queryParameters;
      final network = (params['type'] ?? 'tcp').toLowerCase();
      final security = (params['security'] ?? 'none').toLowerCase();
      final tls = security == 'tls' || security == 'reality' || security == 'xtls';

      String? name;
      if (uri.fragment.isNotEmpty) {
        name = Uri.decodeComponent(uri.fragment);
      }
      name ??= '${uri.host}:${uri.port}';

      return VlessProxy(
        name: name,
        uuid: uri.userInfo,
        server: uri.host,
        port: uri.port,
        network: network,
        encryption: params['encryption'] ?? 'none',
        flow: _emptyToNull(params['flow']),
        tls: tls,
        security: security == 'none' ? null : security,
        sni: _emptyToNull(params['sni'] ?? params['peer']),
        fingerprint: _emptyToNull(params['fp']),
        realityPublicKey: _emptyToNull(params['pbk']),
        realityShortId: _emptyToNull(params['sid']),
        realitySpiderX: _emptyToNull(params['spx']),
        alpn: _emptyToNull(params['alpn']),
        wsPath: _emptyToNull(params['path']),
        wsHost: _emptyToNull(params['host']),
        grpcServiceName: _emptyToNull(params['serviceName']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse a full subscription payload.
  ///
  /// Subscriptions can come in two shapes:
  ///  1. **Plain text** — one share-link per line.
  ///  2. **Base64** — the whole body is base64 of `(1)`.
  static List<VlessProxy> parseSubscription(String body) {
    String text = body.trim();

    // If the body doesn't look like share-links, try base64 decode.
    if (!text.startsWith('vless://') &&
        !text.contains('\nvless://') &&
        _looksBase64(text)) {
      try {
        final decoded = utf8.decode(
          base64.decode(_b64normalize(text)),
          allowMalformed: true,
        );
        text = decoded;
      } catch (_) {
        // fall through — try parsing the raw text anyway
      }
    }

    final out = <VlessProxy>[];
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final p = parseOne(line);
      if (p != null) out.add(p);
    }
    return out;
  }

  static bool _looksBase64(String s) {
    final stripped = s.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(stripped) &&
        stripped.length > 32;
  }

  static String _b64normalize(String s) {
    var v = s.replaceAll(RegExp(r'\s'), '').replaceAll('-', '+').replaceAll('_', '/');
    final pad = v.length % 4;
    if (pad != 0) v = v + '=' * (4 - pad);
    return v;
  }

  static String? _emptyToNull(String? v) =>
      (v == null || v.isEmpty) ? null : v;
}
