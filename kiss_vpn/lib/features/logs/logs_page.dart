import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mihomo/mihomo_api.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/section_header.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _api = MihomoApi();
  final _scroll = ScrollController();
  StreamSubscription<LogEntry>? _sub;
  final List<LogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _sub = _api.logsStream(level: 'info').listen(
      (e) {
        setState(() {
          _entries.add(e);
          if (_entries.length > 500) _entries.removeAt(0);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      },
      onError: (_) {/* core ещё не запущен — поток придёт позже */},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Color _color(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return KissColors.danger;
      case 'warning':
        return KissColors.warning;
      case 'debug':
        return KissColors.textLow;
      default:
        return KissColors.textMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KissSpacing.x4, KissSpacing.x3, KissSpacing.x4, KissSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'Диагностика',
            title: 'Логи',
            subtitle: 'Поток событий ядра Mihomo в реальном времени.',
          ),
          const SizedBox(height: KissSpacing.xl),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(KissSpacing.lg),
              decoration: BoxDecoration(
                color: KissColors.bg1.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(KissRadius.md),
                border: Border.all(color: KissColors.stroke, width: 1),
              ),
              child: _entries.isEmpty
                  ? const Center(
                      child: Text(
                        'Ожидаем логи ядра — нажмите «Подключиться» на главной.',
                        style: TextStyle(color: KissColors.textMid),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _entries.length,
                      itemBuilder: (_, i) {
                        final e = _entries[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            '[${e.level.padRight(7)}] ${e.payload}',
                            style: TextStyle(
                              fontFamily:
                                  'JetBrains Mono, Cascadia Mono, Consolas',
                              fontSize: 12.5,
                              color: _color(e.level),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
