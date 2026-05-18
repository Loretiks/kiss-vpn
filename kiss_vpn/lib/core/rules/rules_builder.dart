import 'rule.dart';

/// Translates the user's [SplitRule] list into Clash-Meta routing rules.
///
/// Каждый из семи типов превращается в свой Clash-Meta line:
/// `PROCESS-NAME,chrome.exe,GROUP` (Процесс), `DOMAIN-SUFFIX,...` (По
/// суффиксу), `DOMAIN-KEYWORD,...` (Слово в домене), `GEOSITE,...`
/// (Smart), `IP-CIDR,1.1.1.1/24,GROUP,no-resolve`, `IP-ASN,13335,...`,
/// `GEOIP,RU,...` — и в конце `MATCH,DEFAULT`.
///
/// Замечание про PROCESS-NAME: работает только когда Mihomo видит
/// source-процесс — в TUN-режиме. В proxy-only режиме источник всех
/// запросов это сам mixed-port, поэтому app-правила тихо игнорируются и
/// решает MATCH-фолбэк. Domain/IP/GeoSite/GeoIP/ASN работают в обоих.
class RulesBuilder {
  static String build({
    required Iterable<SplitRule> rules,
    required String proxyTarget,
    String defaultTarget = 'DIRECT',
  }) {
    final lines = <String>[];
    for (final r in rules) {
      if (!r.enabled) continue;
      final target = r.viaVpn ? proxyTarget : 'DIRECT';
      final line = _ruleLine(r, target);
      if (line != null) lines.add(line);
    }
    lines.add('MATCH,$defaultTarget');
    return lines.map((l) => '  - $l').join('\n');
  }

  static String? _ruleLine(SplitRule r, String target) {
    final v = r.value.trim();
    if (v.isEmpty) return null;
    switch (r.kind) {
      case RuleKind.app:
        return 'PROCESS-NAME,$v,$target';
      case RuleKind.suffix:
        final norm = v.toLowerCase().replaceFirst(RegExp(r'^\*\.'), '');
        return 'DOMAIN-SUFFIX,$norm,$target';
      case RuleKind.keyword:
        return 'DOMAIN-KEYWORD,${v.toLowerCase()},$target';
      case RuleKind.geosite:
        return 'GEOSITE,${v.toLowerCase()},$target';
      case RuleKind.ipCidr:
        final spec = v.contains('/') ? v : '$v/32';
        return 'IP-CIDR,$spec,$target,no-resolve';
      case RuleKind.asn:
        // Allow `AS13335`, `13335`, or `13335 (Cloudflare)` — take the
        // first run of digits.
        final digits = RegExp(r'\d+').firstMatch(v)?.group(0);
        if (digits == null) return null;
        return 'IP-ASN,$digits,$target,no-resolve';
      case RuleKind.geoip:
        return 'GEOIP,${v.toUpperCase()},$target,no-resolve';
    }
  }
}
