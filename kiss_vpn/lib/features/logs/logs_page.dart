import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mihomo/mihomo_api.dart';
import '../../shared/theme/kiss_theme.dart';
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
    _sub?.cancel();
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
      onError: (_) {
        // Core stopped or restarted — retry after a brief delay
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

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Color _color(String level, KissTheme t) {
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

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
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
                color: t.bg1.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(KissRadius.md),
                border: Border.all(color: t.stroke, width: 1),
              ),
              child: _entries.isEmpty
                  ? Center(
                      child: Text(
                        'Ожидаем логи ядра — нажмите «Подключиться» на главной.',
                        style: TextStyle(color: t.textMid),
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
                              color: _color(e.level, t),
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
