import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';

/// Single segmented control rendered as a rounded pill with an animated
/// gradient thumb. Used on the home screen for `Правила` and `Режим`.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final List<PillItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KissSpacing.md, vertical: KissSpacing.sm),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(KissRadius.pill),
        border: Border.all(color: t.stroke, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: t.textLow),
            const SizedBox(width: KissSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: t.textLow,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: KissSpacing.md),
          for (final item in items)
            _PillItemWidget<T>(
              item: item,
              selected: item.value == value,
              onTap: () => onChanged(item.value),
            ),
        ],
      ),
    );
  }
}

class PillItem<T> {
  const PillItem({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class _PillItemWidget<T> extends StatelessWidget {
  const _PillItemWidget({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: KissDurations.fast,
            padding: const EdgeInsets.symmetric(
                horizontal: KissSpacing.md, vertical: KissSpacing.xs + 2),
            decoration: BoxDecoration(
              gradient: selected ? KissGradients.brand : null,
              borderRadius: BorderRadius.circular(KissRadius.pill),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: t.accent.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: -3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 13, color: Colors.white.withValues(
                      alpha: selected ? 1.0 : 0.5)),
                  const SizedBox(width: 6),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: selected ? Colors.white : t.textMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
