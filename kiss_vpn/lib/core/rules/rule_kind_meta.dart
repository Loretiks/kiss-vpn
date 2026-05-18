import 'package:flutter/material.dart';

import 'rule.dart';

/// Per-kind UI metadata: chip label, icon, hint placeholder, helper text.
/// Centralised so the editor dialog and the rule row stay in sync.
class RuleKindMeta {
  const RuleKindMeta({
    required this.label,
    required this.icon,
    required this.valueLabel,
    required this.valuePlaceholder,
    required this.helper,
  });

  final String label;
  final IconData icon;
  final String valueLabel;
  final String valuePlaceholder;
  final String helper;

  static const Map<RuleKind, RuleKindMeta> all = {
    RuleKind.app: RuleKindMeta(
      label: 'Процесс',
      icon: Icons.grid_view_rounded,
      valueLabel: 'Процесс',
      valuePlaceholder: 'chrome.exe',
      helper: 'Имя процесса, напр.: discord.exe, telegram.exe',
    ),
    RuleKind.suffix: RuleKindMeta(
      label: 'По суффиксу',
      icon: Icons.language_rounded,
      valueLabel: 'Суффикс домена',
      valuePlaceholder: 'google.com',
      helper: 'Суффикс домена, напр.: google.com, github.com',
    ),
    RuleKind.keyword: RuleKindMeta(
      label: 'Слово в домене',
      icon: Icons.text_fields_rounded,
      valueLabel: 'Слово в домене',
      valuePlaceholder: 'google',
      helper: 'Ключевое слово в домене, напр.: google, netflix',
    ),
    RuleKind.geosite: RuleKindMeta(
      label: 'GeoSite',
      icon: Icons.menu_book_rounded,
      valueLabel: 'GeoSite',
      valuePlaceholder: 'telegram',
      helper: 'Категория из GeoSite.dat, напр.: telegram, youtube',
    ),
    RuleKind.ipCidr: RuleKindMeta(
      label: 'IP-CIDR',
      icon: Icons.router_rounded,
      valueLabel: 'IP-CIDR',
      valuePlaceholder: '1.1.1.1/24',
      helper: 'IP-диапазон в формате CIDR, напр.: 1.1.1.1/24',
    ),
    RuleKind.asn: RuleKindMeta(
      label: 'ASN',
      icon: Icons.tag_rounded,
      valueLabel: 'ASN',
      valuePlaceholder: '13335',
      helper: 'ASN номер провайдера, напр.: 13335 (Cloudflare)',
    ),
    RuleKind.geoip: RuleKindMeta(
      label: 'GeoIP',
      icon: Icons.place_rounded,
      valueLabel: 'GeoIP',
      valuePlaceholder: 'RU',
      helper: 'IP-диапазоны по стране/сервису, напр.: RU, telegram',
    ),
  };

  static RuleKindMeta of(RuleKind k) => all[k]!;
}
