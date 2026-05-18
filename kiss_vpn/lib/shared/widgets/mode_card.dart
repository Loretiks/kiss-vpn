import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Compact selectable card for the Mode page — `Весь ПК` / `По приложениям`.
/// Icon-left layout, radio dot on the right, gradient border when active.
class ModeCard extends StatefulWidget {
  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding: const EdgeInsets.all(KissSpacing.lg),
          decoration: BoxDecoration(
            color: widget.selected
                ? KissColors.pink.withValues(alpha: 0.06)
                : KissColors.bg2.withValues(alpha: _hover ? 0.85 : 0.6),
            borderRadius: BorderRadius.circular(KissRadius.md),
            border: Border.all(
              color: widget.selected
                  ? KissColors.pink.withValues(alpha: 0.5)
                  : (_hover
                      ? KissColors.strokeBright
                      : KissColors.stroke),
              width: widget.selected ? 1.4 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: KissColors.pink.withValues(alpha: 0.18),
                      blurRadius: 22,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: widget.selected ? KissGradients.brand : null,
                  color: widget.selected ? null : KissColors.bg3,
                  borderRadius: BorderRadius.circular(KissRadius.sm),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.selected ? Colors.white : KissColors.textMid,
                  size: 22,
                ),
              ),
              const SizedBox(width: KissSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: KissColors.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: KissColors.textMid,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KissSpacing.md),
              AnimatedContainer(
                duration: KissDurations.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.selected ? KissGradients.brand : null,
                  border: widget.selected
                      ? null
                      : Border.all(
                          color: KissColors.strokeBright, width: 1.5),
                ),
                child: widget.selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
