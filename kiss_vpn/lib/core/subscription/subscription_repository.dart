import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

import '../storage/secrets_store.dart';
import 'device_identity.dart';
import 'sub_fetcher.dart';
import 'vless_parser.dart';
import 'vless_proxy.dart';

/// Stores and refreshes the user's subscription.
///
/// The subscription URL is sensitive (it acts as a bearer token for the
/// kissmain.ru panel). MVP keeps it in plain SharedPreferences via
/// [SecretsStore] — Phase 5 swaps in a DPAPI wrapper.
///
/// kissmain.ru serves two formats depending on the User-Agent:
///   * `clash.meta` / `mihomo` UA → full Clash YAML (preferred — it carries
///     the panel's curated rules and groups).
///   * anything else → base64 list of `vless://` URLs.
///
/// We always request the Clash YAML so Mihomo can run the config verbatim.
/// We additionally parse out the proxy list so the UI can render server cards
/// without depending on a YAML walker at render time.
class SubscriptionRepository {
  SubscriptionRepository({
    required SecretsStore store,
    SubFetcher? fetcher,
  })  : _store = store,
        _fetcher = fetcher ?? SubFetcher();

  static const _kUrl = 'kiss.sub.url';
  static const _kClashYaml = 'kiss.sub.clash';
  static const _kProxyList = 'kiss.sub.proxies';
  static const _kLastUpdate = 'kiss.sub.updatedAt';
  static const _kInfo = 'kiss.sub.info';

  final SecretsStore _store;
  final SubFetcher _fetcher;

  Future<String?> getUrl() => _store.read(_kUrl);

  Future<void> setUrl(String? url) async {
    await _store.write(_kUrl, (url == null || url.isEmpty) ? null : url);
  }

  Future<DateTime?> lastUpdate() async {
    final raw = await _store.read(_kLastUpdate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<SubInfo?> cachedInfo() async {
    final raw = await _store.read(_kInfo);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SubInfo(
      upload: m['upload'] as int? ?? 0,
      download: m['download'] as int? ?? 0,
      total: m['total'] as int? ?? 0,
      expire: m['expire'] == null
          ? null
          : DateTime.tryParse(m['expire'] as String),
    );
  }

  /// Returns the cached Clash YAML, or null if we have never fetched one yet.
  Future<String?> cachedClashYaml() => _store.read(_kClashYaml);

  /// Returns the cached proxy list (parsed names + endpoints for UI).
  Future<List<VlessProxy>> loadProxies() async {
    final raw = await _store.read(_kProxyList);
    if (raw == null) return refresh();
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(_proxyFromMap).toList();
  }

  /// Hits the subscription URL, replaces the cached config + proxy list,
  /// returns parsed proxies for the UI.
  Future<List<VlessProxy>> refresh() async {
    final url = await getUrl();
    if (url == null || url.isEmpty) {
      throw StateError('No subscription URL configured');
    }
    final resp = await _fetcher.fetch(url);
    final body = resp.body.trim();

    final clashYaml = _looksLikeClash(body) ? body : null;
    final proxies = clashYaml != null
        ? _proxiesFromClash(clashYaml)
        : VlessParser.parseSubscription(body);

    if (clashYaml != null) {
      await _store.write(_kClashYaml, clashYaml);
    } else {
      // Plan B — we received vless URLs. Don't cache as clash yaml; the
      // controller will build one via ConfigWriter from the proxy list.
      await _store.write(_kClashYaml, null);
    }

    await _store.write(_kProxyList, jsonEncode(proxies.map(_proxyToMap).toList()));
    await _store.write(_kLastUpdate, DateTime.now().toIso8601String());

    final info = resp.info;
    if (info != null) {
      await _store.write(
        _kInfo,
        jsonEncode({
          'upload': info.upload,
          'download': info.download,
          'total': info.total,
          'expire': info.expire?.toIso8601String(),
        }),
      );
    }

    return proxies;
  }

  // -------- helpers -------------------------------------------------------

  /// True if [body] looks like a Clash / Mihomo YAML config (rather than a
  /// raw / base64 list of vless URLs).
  static bool _looksLikeClash(String body) {
    final head = body.trimLeft();
    return head.startsWith('mixed-port:') ||
        head.startsWith('port:') ||
        head.startsWith('proxies:') ||
        head.startsWith('proxy-groups:') ||
        head.contains('\nproxies:');
  }

  /// Walk a clash YAML config and pull out the `proxies:` block as
  /// [VlessProxy] DTOs. Non-vless proxies are skipped (we can render them
  /// later as generic entries if needed).
  static List<VlessProxy> _proxiesFromClash(String yamlText) {
    final doc = loadYaml(yamlText);
    if (doc is! YamlMap) return const [];
    final raw = doc['proxies'];
    if (raw is! YamlList) return const [];

    final out = <VlessProxy>[];
    for (final entry in raw) {
      if (entry is! YamlMap) continue;
      final type = (entry['type'] ?? '').toString().toLowerCase();
      if (type != 'vless') continue;
      final reality = entry['reality-opts'];
      out.add(VlessProxy(
        name: (entry['name'] ?? '').toString(),
        uuid: (entry['uuid'] ?? '').toString(),
        server: (entry['server'] ?? '').toString(),
        port: (entry['port'] as num?)?.toInt() ?? 0,
        network: (entry['network'] ?? 'tcp').toString(),
        flow: entry['flow']?.toString(),
        tls: entry['tls'] == true || reality is YamlMap,
        security: reality is YamlMap ? 'reality' : (entry['tls'] == true ? 'tls' : null),
        sni: entry['servername']?.toString() ?? entry['sni']?.toString(),
        fingerprint: entry['client-fingerprint']?.toString(),
        realityPublicKey: reality is YamlMap ? reality['public-key']?.toString() : null,
        realityShortId: reality is YamlMap ? reality['short-id']?.toString() : null,
      ));
    }
    return out;
  }

  static Map<String, dynamic> _proxyToMap(VlessProxy p) => {
        'name': p.name,
        'uuid': p.uuid,
        'server': p.server,
        'port': p.port,
        'network': p.network,
        'flow': p.flow,
        'tls': p.tls,
        'security': p.security,
        'sni': p.sni,
        'fingerprint': p.fingerprint,
        'pbk': p.realityPublicKey,
        'sid': p.realityShortId,
      };

  static VlessProxy _proxyFromMap(Map<String, dynamic> m) => VlessProxy(
        name: m['name'] as String? ?? '',
        uuid: m['uuid'] as String? ?? '',
        server: m['server'] as String? ?? '',
        port: m['port'] as int? ?? 0,
        network: m['network'] as String? ?? 'tcp',
        flow: m['flow'] as String?,
        tls: m['tls'] as bool? ?? false,
        security: m['security'] as String?,
        sni: m['sni'] as String?,
        fingerprint: m['fingerprint'] as String?,
        realityPublicKey: m['pbk'] as String?,
        realityShortId: m['sid'] as String?,
      );
}

final secretsStoreProvider = Provider<SecretsStore>(
    (ref) => throw UnimplementedError('Override secretsStoreProvider in ProviderScope'));

/// Holds the [DeviceIdentity] loaded once at app startup (see main.dart).
/// Overridden in [ProviderScope]; reading it without an override throws.
final deviceIdentityProvider = Provider<DeviceIdentity>(
    (ref) => throw UnimplementedError('Override deviceIdentityProvider in ProviderScope'));

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    store: ref.watch(secretsStoreProvider),
    fetcher: SubFetcher(identity: ref.watch(deviceIdentityProvider)),
  );
});

/// Bumped after every subscription refresh so [proxiesProvider] re-runs.
final subVersionProvider = StateProvider<int>((ref) => 0);

/// Cached proxy list. Reads from disk asynchronously, then any widget can
/// `ref.watch` it and re-render when a refresh updates the cache.
final proxiesProvider = FutureProvider<List<VlessProxy>>((ref) async {
  ref.watch(subVersionProvider);
  return await ref.watch(subscriptionRepositoryProvider).loadProxies();
});
