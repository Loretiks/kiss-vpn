import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

/// Compact metric card — `Загрузка / Скачивание` on the home screen.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.icon,
    required this.bytesPerSecond,
    required this.totalBytes,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int bytesPerSecond;
  final int totalBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(KissSpacing.lg),
      decoration: BoxDecoration(
        color: t.bg2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: t.stroke, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: KissSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: t.textMid,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Format.bytes(bytesPerSecond)}/с',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: t.textHi,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Всего ${Format.bytes(totalBytes)}',
                  style: TextStyle(
                    color: t.textLow,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
