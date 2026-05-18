import 'package:flutter/material.dart';

import '../../core/rules/rule.dart';
import '../../core/rules/rule_kind_meta.dart';
import '../theme/tokens.dart';

/// Single split-tunnel rule row.
///
/// Layout: drag handle · kind-coloured icon tile · name + value · route
/// badge (VPN / NO VPN) · toggle · edit · delete.
class RuleRow extends StatefulWidget {
  const RuleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.color,
    required this.viaVpn,
    required this.enabled,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final RuleKind kind;
  final Color color;
  final bool viaVpn;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends State<RuleRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dim = !widget.enabled;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: KissDurations.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: KissSpacing.md, vertical: KissSpacing.sm + 2),
        decoration: BoxDecoration(
          color: _hover
              ? KissColors.bg2
              : KissColors.bg2.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(KissRadius.md),
          border: Border.all(
            color: _hover ? KissColors.strokeBright : KissColors.stroke,
          ),
        ),
        child: Opacity(
          opacity: dim ? 0.55 : 1.0,
          child: Row(
            children: [
              const _DragHandle(),
              const SizedBox(width: KissSpacing.sm),
              _KindIcon(kind: widget.kind, color: widget.color),
              const SizedBox(width: KissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: KissColors.textHi,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: KissColors.textLow,
                        fontSize: 11.5,
                        fontFamily: 'JetBrains Mono, Consolas, monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _RouteBadge(viaVpn: widget.viaVpn),
              const SizedBox(width: KissSpacing.md),
              Transform.scale(
                scale: 0.85,
                child: Switch(value: widget.enabled, onChanged: widget.onToggle),
              ),
              const SizedBox(width: 2),
              _IconBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Редактировать',
                onTap: widget.onEdit,
              ),
              _IconBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Удалить',
                onTap: widget.onDelete,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 22,
        child: Icon(Icons.drag_indicator,
            size: 16, color: KissColors.textDim),
      );
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind, required this.color});
  final RuleKind kind;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final icon = RuleKindMeta.of(kind).icon;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.viaVpn});
  final bool viaVpn;
  @override
  Widget build(BuildContext context) {
    final color = viaVpn ? KissColors.pink : KissColors.textLow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        viaVpn ? 'VPN' : 'NO VPN',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool danger;
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = _hover
        ? (widget.danger ? KissColors.danger : KissColors.textHi)
        : KissColors.textLow;
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.danger
                    ? KissColors.danger.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: color),
        ),
      ),
    );
    return widget.tooltip == null
        ? btn
        : Tooltip(message: widget.tooltip!, child: btn);
  }
}
