import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';

/// Compact horizontal control: icon + label + bold value + cycle hint.
/// Used as a one-liner replacement for chunky multi-row option cards.
class OptionCard extends StatefulWidget {
  const OptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.md + 2, vertical: KissSpacing.sm + 2),
          decoration: BoxDecoration(
            color: t.bg2.withValues(alpha: _hover ? 0.85 : 0.6),
            borderRadius: BorderRadius.circular(KissRadius.md),
            border: Border.all(
              color: _hover
                  ? t.accentAlt.withValues(alpha: 0.5)
                  : t.stroke,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: t.accentAlt),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: t.textMid,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.value,
                style: TextStyle(
                  color: t.textHi,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: t.textDim,
              ),
            ],
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? card
        : Tooltip(message: widget.tooltip!, child: card);
  }
}
