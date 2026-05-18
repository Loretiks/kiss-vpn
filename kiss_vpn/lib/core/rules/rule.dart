import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/settings.dart';

/// Семь типов правил — повторяет шкалу SnowVPN / FlClash.
/// Хранятся под коротким snake_case ключом в JSON; неизвестные значения
/// при чтении мигрируются (см. [_kindFromName]).
enum RuleKind {
  /// `PROCESS-NAME,chrome.exe,...` — работает только в TUN-режиме.
  app,

  /// `DOMAIN-SUFFIX,youtube.com,...` — ловит сам домен + все поддомены.
  suffix,

  /// `DOMAIN-KEYWORD,google,...` — подстрока в имени домена.
  keyword,

  /// `GEOSITE,telegram,...` — категория из `geosite.dat` ("smart").
  geosite,

  /// `IP-CIDR,1.1.1.1/24,...,no-resolve`.
  ipCidr,

  /// `IP-ASN,13335,...,no-resolve` (Cloudflare = 13335).
  asn,

  /// `GEOIP,RU,...,no-resolve` — диапазоны страны из `geoip.dat`.
  geoip,
}

enum VpnRoute { viaVpn, direct }

class SplitRule {
  const SplitRule({
    required this.id,
    required this.kind,
    required this.value,
    required this.label,
    required this.route,
    this.enabled = true,
  });

  final String id;
  final RuleKind kind;
  final String value;
  final String label;
  final VpnRoute route;
  final bool enabled;

  bool get viaVpn => route == VpnRoute.viaVpn;

  SplitRule copyWith({
    RuleKind? kind,
    String? value,
    String? label,
    VpnRoute? route,
    bool? enabled,
  }) =>
      SplitRule(
        id: id,
        kind: kind ?? this.kind,
        value: value ?? this.value,
        label: label ?? this.label,
        route: route ?? this.route,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'value': value,
        'label': label,
        'route': route.name,
        'enabled': enabled,
      };

  static SplitRule fromJson(Map<String, dynamic> m) => SplitRule(
        id: m['id'] as String,
        kind: _kindFromName(m['kind'] as String?),
        value: m['value'] as String,
        label: (m['label'] as String?) ?? (m['value'] as String),
        route: VpnRoute.values.firstWhere((r) => r.name == m['route'],
            orElse: () => VpnRoute.direct),
        enabled: m['enabled'] as bool? ?? true,
      );

  /// Legacy migration — old configs called domain-suffix rules `domain`.
  static RuleKind _kindFromName(String? raw) {
    if (raw == null) return RuleKind.suffix;
    if (raw == 'domain') return RuleKind.suffix;
    return RuleKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => RuleKind.suffix,
    );
  }
}

/// In-memory + SharedPreferences-backed list of split-tunnel rules.
class RulesController extends StateNotifier<List<SplitRule>> {
  RulesController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'kiss.rules.v1';

  static List<SplitRule> _load(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return _seed();
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SplitRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seed();
    }
  }

  /// First-run starter set so the page isn't empty.
  static List<SplitRule> _seed() => [
        const SplitRule(
          id: 'seed-chrome',
          kind: RuleKind.app,
          value: 'chrome.exe',
          label: 'Chrome',
          route: VpnRoute.viaVpn,
        ),
        const SplitRule(
          id: 'seed-discord',
          kind: RuleKind.app,
          value: 'Discord.exe',
          label: 'Discord',
          route: VpnRoute.direct,
        ),
        const SplitRule(
          id: 'seed-youtube',
          kind: RuleKind.suffix,
          value: 'youtube.com',
          label: 'YouTube',
          route: VpnRoute.viaVpn,
        ),
        const SplitRule(
          id: 'seed-kissmain',
          kind: RuleKind.suffix,
          value: 'kissmain.ru',
          label: 'kissmain.ru',
          route: VpnRoute.direct,
        ),
      ];

  Future<void> _save() async {
    final raw = jsonEncode(state.map((r) => r.toJson()).toList());
    await _prefs.setString(_key, raw);
  }

  void add(SplitRule rule) {
    state = [...state, rule];
    _save();
  }

  void update(SplitRule rule) {
    state = [
      for (final r in state) r.id == rule.id ? rule : r,
    ];
    _save();
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    state = list;
    _save();
  }

  String exportJson() =>
      const JsonEncoder.withIndent('  ')
          .convert(state.map((r) => r.toJson()).toList());

  int importJson(String raw) {
    final parsed = jsonDecode(raw) as List;
    final imported = parsed
        .map((e) => SplitRule.fromJson(e as Map<String, dynamic>))
        .toList();
    state = imported;
    _save();
    return imported.length;
  }
}

final rulesControllerProvider =
    StateNotifierProvider<RulesController, List<SplitRule>>((ref) {
  return RulesController(ref.watch(sharedPreferencesProvider));
});
