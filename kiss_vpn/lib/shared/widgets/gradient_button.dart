import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';

/// Primary brand button — pink → violet gradient with a soft outer glow.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: MouseRegion(
        cursor: disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? KissSpacing.lg : KissSpacing.xxl,
              vertical: compact ? KissSpacing.sm + 2 : KissSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              gradient: KissGradients.brand,
              borderRadius: BorderRadius.circular(KissRadius.pill),
              boxShadow: disabled
                  ? null
                  : [
                      BoxShadow(
                        color: t.accent.withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: -4,
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 16 : 18, color: Colors.white),
                  const SizedBox(width: KissSpacing.sm),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                    letterSpacing: 0.2,
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

/// Outline variant — used for secondary actions next to a [GradientButton].
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: MouseRegion(
        cursor: disabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? KissSpacing.lg : KissSpacing.xxl,
              vertical: compact ? KissSpacing.sm + 2 : KissSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(KissRadius.pill),
              border: Border.all(color: t.stroke, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 16 : 18, color: t.textMid),
                  const SizedBox(width: KissSpacing.sm),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: t.textHi,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
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
