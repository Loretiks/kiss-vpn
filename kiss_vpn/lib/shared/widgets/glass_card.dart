import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A flat dark card with an optional 1-px gradient stroke around it.
///
/// Use [selected] = true to "light up" the card with the brand gradient
/// border (signals an active choice in selectable contexts like the mode
/// picker or the active server in a list).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KissSpacing.xl),
    this.selected = false,
    this.onTap,
    this.radius = KissRadius.lg,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? KissGradients.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      child: child,
    );

    final framed = _GradientBorder(
      selected: selected,
      radius: radius,
      child: body,
    );

    if (onTap == null) return framed;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: KissColors.pink.withValues(alpha: 0.08),
        highlightColor: KissColors.pink.withValues(alpha: 0.04),
        child: framed,
      ),
    );
  }
}

class _GradientBorder extends StatelessWidget {
  const _GradientBorder({
    required this.child,
    required this.selected,
    required this.radius,
  });

  final Widget child;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: KissDurations.med,
      decoration: BoxDecoration(
        gradient: selected ? KissGradients.brand : null,
        color: selected ? null : KissColors.stroke,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: KissColors.pink.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(selected ? 1.5 : 1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.5),
        child: child,
      ),
    );
  }
}
