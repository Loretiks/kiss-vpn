import 'package:flutter/material.dart';

import '../../core/subscription/vless_proxy.dart';
import '../theme/tokens.dart';
import '../utils/country.dart';
import 'flag.dart';
import 'glass_card.dart';

/// One row in the Servers list. Shows the flag, name, endpoint, protocol,
/// and a colour-coded latency badge.
class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.proxy,
    required this.selected,
    required this.delayMs,
    required this.onTap,
  });

  final VlessProxy proxy;
  final bool selected;

  /// `null` — never pinged; `0` — timeout; positive — millis.
  final int? delayMs;
  final VoidCallback onTap;

  Color get _latencyColor {
    final d = delayMs;
    if (d == null) return KissColors.textLow;
    if (d == 0) return KissColors.danger;
    if (d < 200) return KissColors.success;
    if (d < 600) return KissColors.warning;
    return KissColors.danger;
  }

  String get _latencyLabel {
    final d = delayMs;
    if (d == null) return '— мс';
    if (d == 0) return 'таймаут';
    return '$d мс';
  }

  @override
  Widget build(BuildContext context) {
    final country = Country.parse(proxy.name);

    return GlassCard(
      onTap: onTap,
      selected: selected,
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.lg, vertical: KissSpacing.md),
      child: Row(
        children: [
          FlagBadge(country: country, size: 44),
          const SizedBox(width: KissSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (country.code != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KissColors.bg3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          country.code!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: KissColors.textMid,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: KissSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        country.clean.isEmpty ? proxy.name : country.clean,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: KissColors.textHi,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${proxy.server}:${proxy.port}'
                  '${proxy.security != null ? ' · ${proxy.security}' : ''}'
                  '${proxy.flow != null ? ' · ${proxy.flow}' : ''}',
                  style: const TextStyle(
                    color: KissColors.textLow,
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: KissSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: _latencyColor.withValues(alpha: 0.12),
              border: Border.all(
                  color: _latencyColor.withValues(alpha: 0.35), width: 1),
              borderRadius: BorderRadius.circular(KissRadius.pill),
            ),
            child: Text(
              _latencyLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _latencyColor,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: KissSpacing.sm),
          AnimatedOpacity(
            duration: KissDurations.fast,
            opacity: selected ? 1.0 : 0.0,
            child: const Padding(
              padding: EdgeInsets.only(left: KissSpacing.xs),
              child: Icon(Icons.check_circle, color: KissColors.pink, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
