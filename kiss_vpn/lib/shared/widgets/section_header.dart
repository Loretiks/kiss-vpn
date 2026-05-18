import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Page title + optional eyebrow + optional action area.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 1.5,
                      color: KissColors.pink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eyebrow!.toUpperCase(),
                      style: const TextStyle(
                        color: KissColors.pink,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KissSpacing.sm),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: KissColors.textMid,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Smaller section divider — used inside pages above a group of cards.
class GroupTitle extends StatelessWidget {
  const GroupTitle({super.key, required this.label, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.xs, 0, KissSpacing.xs, KissSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KissColors.textMid,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              fontSize: 13,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
