import 'package:flutter/material.dart';

import '../../core/rules/rule.dart';
import '../../core/rules/rule_kind_meta.dart';
import '../../shared/theme/kiss_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';
import 'process_picker_dialog.dart';

/// SnowVPN-style editor for a single split-tunnel rule.
///
///   * 7 type chips wrapped in two rows
///   * `Цель правила` group: pick-from-processes (apps only), label, value
///   * `Действие` two big cards: `Через прокси` (active = pink ring) /
///     `Напрямую` (subtle outline)
///   * Primary `Добавить / Сохранить правило` pill
class RuleEditorDialog extends StatefulWidget {
  const RuleEditorDialog({super.key, this.existing});
  final SplitRule? existing;

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  late RuleKind _kind;
  late VpnRoute _route;
  late final TextEditingController _label;
  late final TextEditingController _value;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? RuleKind.app;
    _route = e?.route ?? VpnRoute.viaVpn;
    _label = TextEditingController(text: e?.label ?? '');
    _value = TextEditingController(text: e?.value ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickFromRunning() async {
    final picked = await showDialog<PickedApp>(
      context: context,
      builder: (_) => const ProcessPickerDialog(),
    );
    if (picked == null) return;
    setState(() {
      _kind = RuleKind.app;
      _value.text = picked.exeName;
      if (_label.text.isEmpty) _label.text = picked.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final meta = RuleKindMeta.of(_kind);
    return Dialog(
      backgroundColor: t.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KissRadius.lg),
        side: BorderSide(color: t.stroke),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(KissSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.accentAlt.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.shield_outlined,
                        size: 18, color: t.accentAlt),
                  ),
                  const SizedBox(width: KissSpacing.md),
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? 'Новое правило'
                          : 'Редактирование правила',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: KissSpacing.xl),

              // ── Тип ─────────────────────────────────────────────
              const _SectionLabel('Тип'),
              const SizedBox(height: KissSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in RuleKind.values)
                    _TypeChip(
                      kind: k,
                      selected: _kind == k,
                      onTap: () => setState(() => _kind = k),
                    ),
                ],
              ),

              const SizedBox(height: KissSpacing.lg),

              // ── Цель правила ─────────────────────────────────────
              const _SectionLabel('Цель правила'),
              const SizedBox(height: KissSpacing.sm),
              if (_kind == RuleKind.app) ...[
                GhostButton(
                  label: 'Выбрать из запущенных',
                  icon: Icons.list_alt_rounded,
                  compact: true,
                  onPressed: _pickFromRunning,
                ),
                const SizedBox(height: KissSpacing.sm),
              ],
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  prefixIcon:
                      Icon(Icons.label_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: KissSpacing.sm),
              TextField(
                controller: _value,
                decoration: InputDecoration(
                  labelText: meta.valueLabel,
                  hintText: meta.valuePlaceholder,
                  prefixIcon: Icon(meta.icon, size: 18),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  meta.helper,
                  style: TextStyle(
                    color: t.textLow,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: KissSpacing.lg),

              // ── Действие ────────────────────────────────────────
              const _SectionLabel('Действие'),
              const SizedBox(height: KissSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.shield_rounded,
                      title: 'Через прокси',
                      subtitle: 'Через VPN',
                      selected: _route == VpnRoute.viaVpn,
                      onTap: () =>
                          setState(() => _route = VpnRoute.viaVpn),
                    ),
                  ),
                  const SizedBox(width: KissSpacing.md),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.link_off_rounded,
                      title: 'Напрямую',
                      subtitle: 'Без VPN',
                      selected: _route == VpnRoute.direct,
                      onTap: () =>
                          setState(() => _route = VpnRoute.direct),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: KissSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: KissSpacing.sm),
                    GradientButton(
                      label: widget.existing == null
                          ? 'Добавить правило'
                          : 'Сохранить',
                      icon: Icons.check_rounded,
                      compact: true,
                      onPressed: () {
                        if (_value.text.trim().isEmpty) return;
                        final rule = SplitRule(
                          id: widget.existing?.id ??
                              DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toString(),
                          kind: _kind,
                          value: _value.text.trim(),
                          label: _label.text.trim().isEmpty
                              ? _value.text.trim()
                              : _label.text.trim(),
                          route: _route,
                          enabled: widget.existing?.enabled ?? true,
                        );
                        Navigator.of(context).pop(rule);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: t.textHi,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.help_outline_rounded,
            size: 14, color: t.textDim),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });
  final RuleKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final meta = RuleKindMeta.of(kind);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.12)
                : t.bg2.withValues(alpha: 0.6),
            border: Border.all(
              color: selected
                  ? t.accent.withValues(alpha: 0.6)
                  : t.stroke,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(KissRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                meta.icon,
                size: 14,
                color: selected ? t.accent : t.textLow,
              ),
              const SizedBox(width: 6),
              Text(
                meta.label,
                style: TextStyle(
                  color: selected ? t.textHi : t.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final color = selected ? t.accent : t.textLow;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.lg, vertical: KissSpacing.lg),
          decoration: BoxDecoration(
            color: selected
                ? t.accent.withValues(alpha: 0.06)
                : t.bg2.withValues(alpha: 0.6),
            border: Border.all(
              color: selected
                  ? t.accent.withValues(alpha: 0.6)
                  : t.stroke,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(KissRadius.md),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? t.textHi : t.textMid,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: t.textLow,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
