import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/platform/process_list.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';

/// Result returned from the process picker dialog — the user either chose
/// a running process or browsed for an exe via the file picker.
class PickedApp {
  PickedApp({required this.label, required this.exeName});
  final String label;
  final String exeName;
}

class ProcessPickerDialog extends StatefulWidget {
  const ProcessPickerDialog({super.key});

  @override
  State<ProcessPickerDialog> createState() => _ProcessPickerDialogState();
}

class _ProcessPickerDialogState extends State<ProcessPickerDialog> {
  final _searchCtl = TextEditingController();
  String _query = '';
  List<RunningProcess>? _processes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _processes = null;
      _error = null;
    });
    try {
      final list = await ProcessList.enumerate();
      if (!mounted) return;
      setState(() => _processes = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _browseExe() async {
    final f = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Программы', extensions: ['exe']),
    ]);
    if (f == null) return;
    final name = f.name;
    final label =
        name.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
    if (!mounted) return;
    Navigator.of(context).pop(PickedApp(
      label: label.isEmpty ? name : label,
      exeName: name,
    ));
  }

  Color _colorFor(String name) {
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
    return palette[name.toLowerCase().hashCode.abs() % palette.length];
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Добавить приложение',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Обновить список',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Выберите процесс из списка запущенных приложений.',
                style: TextStyle(color: KissColors.textMid),
              ),
              const SizedBox(height: KissSpacing.lg),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtl,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию или exe-файлу…',
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: KissSpacing.md),
              Expanded(child: _body()),
              const SizedBox(height: KissSpacing.lg),
              Row(
                children: [
                  GhostButton(
                    label: 'Указать .exe вручную',
                    icon: Icons.folder_open_rounded,
                    compact: true,
                    onPressed: _browseExe,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Text(
          'Не удалось получить список процессов:\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: KissColors.danger),
        ),
      );
    }
    if (_processes == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              strokeWidth: 2.6, color: KissColors.pink),
        ),
      );
    }

    final processes = _processes!;
    final filtered = _query.isEmpty
        ? processes
        : processes
            .where((p) =>
                p.name.toLowerCase().contains(_query.toLowerCase()) ||
                p.exeName.toLowerCase().contains(_query.toLowerCase()) ||
                (p.title?.toLowerCase().contains(_query.toLowerCase()) ??
                    false))
            .toList();

    if (processes.isEmpty) {
      return const Center(
        child: Text(
          'Не найдено активных процессов.',
          style: TextStyle(color: KissColors.textMid),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Нет совпадений по запросу «$_query»',
          style: const TextStyle(color: KissColors.textLow),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = filtered[i];
        final hasTitle = p.title != null && p.title!.isNotEmpty;
        return _ProcessTile(
          process: p,
          subtitle: hasTitle ? p.title! : (p.path ?? p.exeName),
          color: _colorFor(p.exeName),
          onTap: () => Navigator.of(context).pop(
            PickedApp(label: p.name, exeName: p.exeName),
          ),
        );
      },
    );
  }
}

class _ProcessTile extends StatefulWidget {
  const _ProcessTile({
    required this.process,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final RunningProcess process;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ProcessTile> createState() => _ProcessTileState();
}

class _ProcessTileState extends State<_ProcessTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.process;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.md, vertical: KissSpacing.sm + 2),
          decoration: BoxDecoration(
            color: _hover
                ? KissColors.pink.withValues(alpha: 0.06)
                : KissColors.bg2.withValues(alpha: 0.6),
            border: Border.all(
              color: _hover
                  ? KissColors.pink.withValues(alpha: 0.4)
                  : KissColors.stroke,
            ),
            borderRadius: BorderRadius.circular(KissRadius.md),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.16),
                  border: Border.all(
                      color: widget.color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  (p.name.isEmpty ? '?' : p.name[0]).toUpperCase(),
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: KissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              color: KissColors.textHi,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.instances > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  KissColors.textLow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '×${p.instances}',
                              style: const TextStyle(
                                color: KissColors.textLow,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
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
              const SizedBox(width: KissSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: _hover ? KissColors.pink : KissColors.textDim,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
