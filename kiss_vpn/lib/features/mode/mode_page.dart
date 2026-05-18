import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rules/rule.dart';
import '../../core/storage/settings.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/mode_card.dart';
import '../../shared/widgets/rule_row.dart';
import 'process_picker_dialog.dart';
import 'rule_editor_dialog.dart';

/// «Режим работы VPN» — выбор маршрутизации (весь ПК / по приложениям) +
/// редактор правил для per-app режима.
class ModePage extends ConsumerWidget {
  const ModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(settingsControllerProvider).scope;
    final controller = ref.read(settingsControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: KissSpacing.xl),
          Row(
            children: [
              Expanded(
                child: ModeCard(
                  icon: Icons.desktop_windows_outlined,
                  title: 'Весь ПК',
                  subtitle: 'Всё через VPN',
                  selected: scope == VpnScope.whole,
                  onTap: () => controller.setScope(VpnScope.whole),
                ),
              ),
              const SizedBox(width: KissSpacing.md),
              Expanded(
                child: ModeCard(
                  icon: Icons.grid_view_rounded,
                  title: 'По приложениям',
                  subtitle: 'Только выбранные',
                  selected: scope == VpnScope.perApp,
                  onTap: () => controller.setScope(VpnScope.perApp),
                ),
              ),
            ],
          ),
          const SizedBox(height: KissSpacing.x3),
          AnimatedSwitcher(
            duration: KissDurations.med,
            child: scope == VpnScope.perApp
                ? const _RulesSection()
                : const _ScopeHint(),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesControllerProvider);
    final enabled = rules.where((r) => r.enabled).length;
    final viaVpn = rules.where((r) => r.enabled && r.viaVpn).length;
    final direct = rules.where((r) => r.enabled && !r.viaVpn).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Маршрутизация',
          style: TextStyle(
            color: KissColors.textLow,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Режим работы VPN',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            _StatChip(label: 'правил', value: '${rules.length}'),
            const SizedBox(width: KissSpacing.sm),
            _StatChip(
              label: 'активно',
              value: '$enabled',
              accent: KissColors.success,
            ),
            const SizedBox(width: KissSpacing.sm),
            _StatChip(
              label: 'VPN',
              value: '$viaVpn',
              accent: KissColors.pink,
            ),
            const SizedBox(width: KissSpacing.sm),
            _StatChip(
              label: 'прямо',
              value: '$direct',
              accent: KissColors.textLow,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Решите, какой трафик идёт в туннель — весь сразу или только из выбранных приложений и сайтов.',
          style: TextStyle(color: KissColors.textMid, height: 1.5),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.accent = KissColors.textMid,
  });
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.7),
        border: Border.all(color: KissColors.stroke),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: KissColors.textHi,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: KissColors.textLow,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeHint extends StatelessWidget {
  const _ScopeHint();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KissSpacing.lg),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: KissColors.textLow, size: 18),
          SizedBox(width: KissSpacing.md),
          Expanded(
            child: Text(
              'В режиме «Весь ПК» правила не применяются — VPN маршрутизирует всё. Чтобы настроить точечный обход, выберите «По приложениям».',
              style: TextStyle(
                color: KissColors.textMid,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesSection extends ConsumerStatefulWidget {
  const _RulesSection();

  @override
  ConsumerState<_RulesSection> createState() => _RulesSectionState();
}

class _RulesSectionState extends ConsumerState<_RulesSection> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Color _colorFor(SplitRule r) {
    const palette = [
      Color(0xFFFF3B7A),
      Color(0xFF7C5CFF),
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFF60A5FA),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFFF97316),
    ];
    return palette[r.id.hashCode.abs() % palette.length];
  }

  Future<void> _addManual() async {
    final result = await showDialog<SplitRule>(
      context: context,
      builder: (_) => const RuleEditorDialog(),
    );
    if (result != null) {
      ref.read(rulesControllerProvider.notifier).add(result);
    }
  }

  Future<void> _addAppViaPicker() async {
    final picked = await showDialog<PickedApp>(
      context: context,
      builder: (_) => const ProcessPickerDialog(),
    );
    if (picked == null) return;
    final rule = SplitRule(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: RuleKind.app,
      value: picked.exeName,
      label: picked.label,
      route: VpnRoute.viaVpn,
    );
    ref.read(rulesControllerProvider.notifier).add(rule);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Добавлено правило: ${picked.label}')),
      );
    }
  }

  Future<void> _editRule(SplitRule rule) async {
    final result = await showDialog<SplitRule>(
      context: context,
      builder: (_) => RuleEditorDialog(existing: rule),
    );
    if (result != null) {
      ref.read(rulesControllerProvider.notifier).update(result);
    }
  }

  Future<void> _confirmDelete(SplitRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: KissColors.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KissRadius.lg),
          side: const BorderSide(color: KissColors.stroke),
        ),
        title: const Text('Удалить правило?'),
        content: Text('«${rule.label}» больше не будет применяться.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: KissColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(rulesControllerProvider.notifier).remove(rule.id);
    }
  }

  Future<void> _importRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final cd = await Clipboard.getData('text/plain');
    final raw = cd?.text;
    if (raw == null || raw.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Буфер обмена пуст — скопируйте JSON-список правил.'),
      ));
      return;
    }
    try {
      final n = ref.read(rulesControllerProvider.notifier).importJson(raw);
      messenger.showSnackBar(
          SnackBar(content: Text('Импортировано правил: $n')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Не удалось импортировать: $e')));
    }
  }

  Future<void> _exportRules() async {
    final messenger = ScaffoldMessenger.of(context);
    final json = ref.read(rulesControllerProvider.notifier).exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    messenger.showSnackBar(const SnackBar(
        content: Text('JSON правил скопирован в буфер обмена.')));
  }

  Future<void> _showTemplates() async {
    final picked = await showDialog<List<SplitRule>>(
      context: context,
      builder: (_) => const _TemplatesDialog(),
    );
    if (picked == null || picked.isEmpty) return;
    final ctl = ref.read(rulesControllerProvider.notifier);
    for (final r in picked) {
      ctl.add(r);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Добавлено правил: ${picked.length}')),
      );
    }
  }

  void _toggleAll(bool enable) {
    final ctl = ref.read(rulesControllerProvider.notifier);
    for (final r in ref.read(rulesControllerProvider)) {
      ctl.update(r.copyWith(enabled: enable));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(rulesControllerProvider);
    final filtered = _query.isEmpty
        ? all
        : all
            .where((r) =>
                r.label.toLowerCase().contains(_query.toLowerCase()) ||
                r.value.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Column(
      key: const ValueKey('rules-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Настройка правил',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: KissColors.textHi,
                ),
              ),
            ),
            _LinkAction(
              icon: Icons.upload_rounded,
              label: 'Экспорт',
              onTap: _exportRules,
            ),
            const SizedBox(width: KissSpacing.md),
            _LinkAction(
              icon: Icons.download_rounded,
              label: 'Импорт',
              onTap: _importRules,
            ),
          ],
        ),
        const SizedBox(height: KissSpacing.md),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Поиск по правилам…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: KissColors.textLow),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchCtl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 0),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: KissSpacing.sm),
            if (all.isNotEmpty)
              _BulkBtn(
                tooltip: 'Включить все',
                icon: Icons.toggle_on_rounded,
                onTap: () => _toggleAll(true),
              ),
            if (all.isNotEmpty)
              _BulkBtn(
                tooltip: 'Выключить все',
                icon: Icons.toggle_off_rounded,
                onTap: () => _toggleAll(false),
              ),
          ],
        ),
        const SizedBox(height: KissSpacing.md),
        Row(
          children: [
            GradientButton(
              label: 'Добавить приложение',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: _addAppViaPicker,
            ),
            const SizedBox(width: KissSpacing.sm),
            GhostButton(
              label: 'Свое правило',
              icon: Icons.edit_note_rounded,
              compact: true,
              onPressed: _addManual,
            ),
            const SizedBox(width: KissSpacing.sm),
            GhostButton(
              label: 'Готовые наборы',
              icon: Icons.auto_awesome_outlined,
              compact: true,
              onPressed: _showTemplates,
            ),
          ],
        ),
        const SizedBox(height: KissSpacing.xl),

        if (all.isEmpty)
          _EmptyState(onAddApp: _addAppViaPicker, onTemplates: _showTemplates)
        else if (filtered.isEmpty)
          _NoMatches(query: _query)
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            onReorder: (oldIdx, newIdx) {
              final oldId = filtered[oldIdx].id;
              final newId = newIdx < filtered.length
                  ? filtered[newIdx].id
                  : filtered.last.id;
              final globalOld = all.indexWhere((r) => r.id == oldId);
              final globalNew = all.indexWhere((r) => r.id == newId);
              if (globalOld < 0 || globalNew < 0) return;
              ref
                  .read(rulesControllerProvider.notifier)
                  .reorder(globalOld, globalNew);
            },
            itemBuilder: (_, i) {
              final r = filtered[i];
              return Padding(
                key: ValueKey(r.id),
                padding: const EdgeInsets.only(bottom: KissSpacing.sm),
                child: ReorderableDragStartListener(
                  index: i,
                  child: RuleRow(
                    title: r.label,
                    subtitle: r.value,
                    kind: r.kind,
                    color: _colorFor(r),
                    viaVpn: r.viaVpn,
                    enabled: r.enabled,
                    onToggle: (v) => ref
                        .read(rulesControllerProvider.notifier)
                        .update(r.copyWith(enabled: v)),
                    onEdit: () => _editRule(r),
                    onDelete: () => _confirmDelete(r),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LinkAction extends StatefulWidget {
  const _LinkAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_LinkAction> createState() => _LinkActionState();
}

class _LinkActionState extends State<_LinkAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = _hover ? KissColors.pink : KissColors.violet;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          children: [
            Icon(widget.icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: KissColors.bg2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(KissRadius.sm),
              border: Border.all(color: KissColors.stroke),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: KissColors.textMid),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KissSpacing.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke),
      ),
      child: Text(
        'Нет правил по запросу «$query»',
        style: const TextStyle(color: KissColors.textLow),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddApp, required this.onTemplates});
  final VoidCallback onAddApp;
  final VoidCallback onTemplates;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KissSpacing.x3),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: KissColors.pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rule_folder_outlined,
                color: KissColors.pink, size: 28),
          ),
          const SizedBox(height: KissSpacing.md),
          const Text(
            'Правил пока нет',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: KissColors.textHi,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Добавьте приложение или сайт чтобы маршрутизировать только их через VPN.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KissColors.textMid, height: 1.5),
          ),
          const SizedBox(height: KissSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GradientButton(
                label: 'Добавить приложение',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: onAddApp,
              ),
              const SizedBox(width: KissSpacing.md),
              GhostButton(
                label: 'Готовые наборы',
                icon: Icons.auto_awesome_outlined,
                compact: true,
                onPressed: onTemplates,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── templates

class _TemplateRule {
  const _TemplateRule({
    required this.label,
    required this.value,
    required this.kind,
    required this.route,
  });
  final String label;
  final String value;
  final RuleKind kind;
  final VpnRoute route;
}

class _Template {
  const _Template({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rules,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_TemplateRule> rules;
}

const _templates = <_Template>[
  _Template(
    title: 'Smart: заблокированные сервисы',
    subtitle: 'YouTube, Twitch, Discord, OpenAI, Twitter и т.д. — через VPN',
    icon: Icons.shield_outlined,
    rules: [
      _TemplateRule(label: 'Smart: Youtube', value: 'youtube', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Twitch', value: 'twitch', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Discord', value: 'discord', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: OpenAI', value: 'openai', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Anthropic', value: 'anthropic', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Twitter', value: 'twitter', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Instagram', value: 'instagram', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Facebook', value: 'facebook', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: TikTok', value: 'tiktok', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Netflix', value: 'netflix', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Telegram', value: 'telegram', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'GeoIP: Telegram', value: 'telegram', kind: RuleKind.geoip, route: VpnRoute.viaVpn),
    ],
  ),
  _Template(
    title: 'Российские сервисы — напрямую',
    subtitle: 'GeoSite + GeoIP RU — банки, Госуслуги, маркетплейсы',
    icon: Icons.flag_circle_outlined,
    rules: [
      _TemplateRule(label: 'Smart: Yandex', value: 'yandex', kind: RuleKind.geosite, route: VpnRoute.direct),
      _TemplateRule(label: 'Smart: VK', value: 'vk', kind: RuleKind.geosite, route: VpnRoute.direct),
      _TemplateRule(label: 'Smart: mail.ru', value: 'mailru', kind: RuleKind.geosite, route: VpnRoute.direct),
      _TemplateRule(label: 'Сбер', value: 'sber.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'mos.ru', value: 'mos.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'Госуслуги', value: 'gosuslugi.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'Тинькофф', value: 'tinkoff.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'Ozon', value: 'ozon.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'Wildberries', value: 'wildberries.ru', kind: RuleKind.suffix, route: VpnRoute.direct),
      _TemplateRule(label: 'GeoIP: RU', value: 'RU', kind: RuleKind.geoip, route: VpnRoute.direct),
    ],
  ),
  _Template(
    title: 'Стриминг — через VPN',
    subtitle: 'Netflix, Spotify, Apple Music, SoundCloud',
    icon: Icons.live_tv_outlined,
    rules: [
      _TemplateRule(label: 'Smart: Netflix', value: 'netflix', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Spotify', value: 'spotify', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'Smart: Apple', value: 'apple', kind: RuleKind.geosite, route: VpnRoute.viaVpn),
      _TemplateRule(label: 'SoundCloud', value: 'soundcloud.com', kind: RuleKind.suffix, route: VpnRoute.viaVpn),
    ],
  ),
  _Template(
    title: 'Игры — напрямую',
    subtitle: 'Steam, Epic, Battle.net, Riot — для низкого пинга',
    icon: Icons.sports_esports_outlined,
    rules: [
      _TemplateRule(label: 'Steam', value: 'Steam.exe', kind: RuleKind.app, route: VpnRoute.direct),
      _TemplateRule(label: 'Epic Games', value: 'EpicGamesLauncher.exe', kind: RuleKind.app, route: VpnRoute.direct),
      _TemplateRule(label: 'Battle.net', value: 'Battle.net.exe', kind: RuleKind.app, route: VpnRoute.direct),
      _TemplateRule(label: 'Riot Client', value: 'RiotClientServices.exe', kind: RuleKind.app, route: VpnRoute.direct),
      _TemplateRule(label: 'GTA5', value: 'GTA5.exe', kind: RuleKind.app, route: VpnRoute.direct),
      _TemplateRule(label: 'Smart: Steam', value: 'steam', kind: RuleKind.geosite, route: VpnRoute.direct),
    ],
  ),
  _Template(
    title: 'Cloudflare CDN',
    subtitle: 'IP диапазоны Cloudflare (AS13335) — через VPN',
    icon: Icons.cloud_queue_rounded,
    rules: [
      _TemplateRule(label: 'ASN: Cloudflare', value: '13335', kind: RuleKind.asn, route: VpnRoute.viaVpn),
    ],
  ),
];

class _TemplatesDialog extends StatefulWidget {
  const _TemplatesDialog();
  @override
  State<_TemplatesDialog> createState() => _TemplatesDialogState();
}

class _TemplatesDialogState extends State<_TemplatesDialog> {
  final _picked = <int>{};

  List<SplitRule> _build() {
    final out = <SplitRule>[];
    var i = 0;
    for (final idx in _picked) {
      final t = _templates[idx];
      for (final r in t.rules) {
        out.add(SplitRule(
          id: '${DateTime.now().microsecondsSinceEpoch}-${i++}',
          kind: r.kind,
          value: r.value,
          label: r.label,
          route: r.route,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KissColors.bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KissRadius.lg),
        side: const BorderSide(color: KissColors.stroke),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(KissSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Готовые наборы',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Выберите один или несколько — правила добавятся в общий список.',
                style: TextStyle(color: KissColors.textMid),
              ),
              const SizedBox(height: KissSpacing.lg),
              Expanded(
                child: ListView.separated(
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: KissSpacing.sm),
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    final picked = _picked.contains(i);
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (picked) {
                            _picked.remove(i);
                          } else {
                            _picked.add(i);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: KissDurations.fast,
                          padding: const EdgeInsets.all(KissSpacing.md + 2),
                          decoration: BoxDecoration(
                            color: picked
                                ? KissColors.pink.withValues(alpha: 0.08)
                                : KissColors.bg2,
                            borderRadius:
                                BorderRadius.circular(KissRadius.md),
                            border: Border.all(
                              color: picked
                                  ? KissColors.pink.withValues(alpha: 0.5)
                                  : KissColors.stroke,
                              width: picked ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: KissColors.violet
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(t.icon,
                                    color: KissColors.violet, size: 20),
                              ),
                              const SizedBox(width: KissSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: const TextStyle(
                                        color: KissColors.textHi,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.rules.length} правил · ${t.subtitle}',
                                      style: const TextStyle(
                                        color: KissColors.textMid,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                picked
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: picked
                                    ? KissColors.pink
                                    : KissColors.textDim,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: KissSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: KissSpacing.sm),
                  GradientButton(
                    label: _picked.isEmpty
                        ? 'Выберите наборы'
                        : 'Добавить ${_build().length}',
                    icon: Icons.add_rounded,
                    compact: true,
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_build()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
