import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/app_log.dart';
import '../../core/mihomo/mihomo_api.dart';
import '../../shared/theme/kiss_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/section_header.dart';

enum _LogSource { app, core }

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _api = MihomoApi();
  final _scroll = ScrollController();
  StreamSubscription<LogEntry>? _sub;
  StreamSubscription<AppLogEntry>? _appSub;
  final List<LogEntry> _coreEntries = [];
  _LogSource _source = _LogSource.app;

  @override
  void initState() {
    super.initState();
    _attach();
    _appSub = AppLog.instance.stream.listen((_) {
      if (mounted) setState(() {});
      _autoscroll();
    });
  }

  void _attach() {
    _sub?.cancel();
    _sub = _api.logsStream(level: 'info').listen(
      (e) {
        setState(() {
          _coreEntries.add(e);
          if (_coreEntries.length > 500) _coreEntries.removeAt(0);
        });
        _autoscroll();
      },
      onError: (_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _attach();
        });
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _attach();
        });
      },
    );
  }

  void _autoscroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _appSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copyForBugReport() async {
    final text = await AppLog.instance.exportAsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Логи скопированы в буфер обмена — вставьте в чат поддержки.'),
      ),
    );
  }

  Future<void> _saveToFile() async {
    final path = await AppLog.instance.exportAsFile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Сохранено: $path'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => launchUrl(Uri.file(path)),
        ),
      ),
    );
  }

  Color _coreColor(String level, KissTheme t) {
    switch (level.toLowerCase()) {
      case 'error':
        return t.danger;
      case 'warning':
        return t.warning;
      case 'debug':
        return t.textLow;
      default:
        return t.textMid;
    }
  }

  Color _appColor(LogLevel level, KissTheme t) {
    switch (level) {
      case LogLevel.error:
        return t.danger;
      case LogLevel.warn:
        return t.warning;
      case LogLevel.debug:
        return t.textLow;
      case LogLevel.info:
        return t.textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final appEntries = AppLog.instance.entries;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Диагностика',
            title: 'Логи',
            subtitle:
                'Все события клиента + поток ядра Mihomo. Кнопка «Для багрепорта» собирает всё в буфер обмена для отправки в поддержку.',
          ),
          const SizedBox(height: KissSpacing.xl),
          Row(
            children: [
              SegmentedButton<_LogSource>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: t.accent.withValues(alpha: 0.18),
                  selectedForegroundColor: t.accent,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 34),
                ),
                segments: [
                  ButtonSegment(
                    value: _LogSource.app,
                    label: Text('Клиент (${appEntries.length})'),
                  ),
                  ButtonSegment(
                    value: _LogSource.core,
                    label: Text('Ядро (${_coreEntries.length})'),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: (v) => setState(() => _source = v.first),
              ),
              const Spacer(),
              GhostButton(
                label: 'Очистить',
                icon: Icons.clear_all_rounded,
                compact: true,
                onPressed: () => setState(() {
                  if (_source == _LogSource.app) {
                    AppLog.instance.clear();
                  } else {
                    _coreEntries.clear();
                  }
                }),
              ),
              const SizedBox(width: KissSpacing.sm),
              GhostButton(
                label: 'В файл',
                icon: Icons.save_rounded,
                compact: true,
                onPressed: _saveToFile,
              ),
              const SizedBox(width: KissSpacing.sm),
              GradientButton(
                label: 'Для багрепорта',
                icon: Icons.copy_rounded,
                compact: true,
                onPressed: _copyForBugReport,
              ),
            ],
          ),
          const SizedBox(height: KissSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(KissSpacing.lg),
              decoration: BoxDecoration(
                color: t.bg1.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(KissRadius.md),
                border: Border.all(color: t.stroke, width: 1),
              ),
              child: _source == _LogSource.app
                  ? _buildAppLogs(appEntries, t)
                  : _buildCoreLogs(t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogs(List<AppLogEntry> entries, KissTheme t) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Лог пуст. События будут появляться по мере работы клиента.',
          style: TextStyle(color: t.textMid),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SelectableText(
            e.format(),
            style: TextStyle(
              fontFamily: 'JetBrains Mono, Cascadia Mono, Consolas',
              fontSize: 12.5,
              color: _appColor(e.level, t),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoreLogs(KissTheme t) {
    if (_coreEntries.isEmpty) {
      return Center(
        child: Text(
          'Ожидаем логи ядра — нажмите «Подключиться» на главной.',
          style: TextStyle(color: t.textMid),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _coreEntries.length,
      itemBuilder: (_, i) {
        final e = _coreEntries[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SelectableText(
            '[${e.level.padRight(7)}] ${e.payload}',
            style: TextStyle(
              fontFamily: 'JetBrains Mono, Cascadia Mono, Consolas',
              fontSize: 12.5,
              color: _coreColor(e.level, t),
            ),
          ),
        );
      },
    );
  }
}
