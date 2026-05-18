import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/updater/update_controller.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/utils/format.dart';

/// Update-management card rendered inside the Settings page.
///
/// Walks the user through: check → available → downloading → ready → install.
/// Each phase is mutually exclusive, so we can layout it as a single card
/// with a body that swaps between progress UI, action buttons, etc.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(updateControllerProvider);
    final ctl = ref.read(updateControllerProvider.notifier);

    Color accent;
    String title;
    String? subtitle;
    Widget action;

    switch (st.phase) {
      case UpdatePhase.idle:
        accent = KissColors.textLow;
        title = 'Версия ${st.currentVersion.isEmpty ? '…' : st.currentVersion}';
        subtitle = 'Установлена последняя версия.';
        action = _ghostBtn(
          label: 'Проверить обновления',
          icon: Icons.refresh_rounded,
          onTap: ctl.check,
        );
        break;
      case UpdatePhase.checking:
        accent = KissColors.violet;
        title = 'Проверяем обновления…';
        subtitle = 'Запрос к GitHub Releases.';
        action = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: KissColors.violet),
        );
        break;
      case UpdatePhase.available:
        final info = st.info!;
        accent = KissColors.pink;
        title = 'Доступна версия ${info.version}';
        subtitle = info.notes.trim().isEmpty
            ? 'Размер: ${Format.bytes(info.installerSize)}'
            : '${Format.bytes(info.installerSize)} · ${_firstLine(info.notes)}';
        action = Wrap(
          spacing: 6,
          children: [
            _ghostBtn(
              label: 'Подробнее',
              icon: Icons.open_in_new_rounded,
              onTap: () => _open(info.releaseUrl),
            ),
            _filledBtn(
              label: 'Скачать',
              icon: Icons.download_rounded,
              onTap: ctl.download,
            ),
          ],
        );
        break;
      case UpdatePhase.downloading:
        final pct = (st.progress * 100).clamp(0, 100).toStringAsFixed(0);
        accent = KissColors.pink;
        title = 'Загрузка ${st.info?.version ?? ''} · $pct%';
        subtitle = '${Format.bytes(st.received)} из ${Format.bytes(st.total)}';
        action = _ghostBtn(
          label: 'Отмена',
          icon: Icons.close_rounded,
          onTap: ctl.cancelDownload,
        );
        break;
      case UpdatePhase.ready:
        accent = KissColors.success;
        title = 'Готово к установке — версия ${st.info?.version ?? ''}';
        subtitle =
            'Приложение закроется, запустится installer и снова откроет окно.';
        action = _filledBtn(
          label: 'Установить и перезапустить',
          icon: Icons.refresh_rounded,
          onTap: ctl.install,
        );
        break;
      case UpdatePhase.installing:
        accent = KissColors.success;
        title = 'Запускаем installer…';
        subtitle = 'Окно сейчас закроется.';
        action = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2.2, color: KissColors.success),
        );
        break;
      case UpdatePhase.error:
        accent = KissColors.danger;
        title = 'Не удалось проверить обновления';
        subtitle = st.error;
        action = _ghostBtn(
          label: 'Повторить',
          icon: Icons.refresh_rounded,
          onTap: ctl.check,
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(KissSpacing.lg),
      decoration: BoxDecoration(
        color: KissColors.bg2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(KissRadius.md),
        border: Border.all(color: KissColors.stroke, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  st.phase == UpdatePhase.available
                      ? Icons.system_update_rounded
                      : Icons.cloud_download_outlined,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: KissSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: KissColors.textHi,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: KissColors.textMid,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (st.phase == UpdatePhase.downloading) ...[
            const SizedBox(height: KissSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: st.progress,
                minHeight: 6,
                backgroundColor: KissColors.bg3,
                valueColor: const AlwaysStoppedAnimation(KissColors.pink),
              ),
            ),
          ],
          const SizedBox(height: KissSpacing.md),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }

  String _firstLine(String s) {
    final line = s.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    if (line.length <= 80) return line;
    return '${line.substring(0, 77)}…';
  }

  void _open(String url) {
    if (url.isEmpty) return;
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _ghostBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return _Btn(
      label: label,
      icon: icon,
      onTap: onTap,
      filled: false,
    );
  }

  Widget _filledBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return _Btn(
      label: label,
      icon: icon,
      onTap: onTap,
      filled: true,
    );
  }
}

class _Btn extends StatefulWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.filled ? KissGradients.brand : null,
            color: widget.filled
                ? null
                : (_hover ? KissColors.bg3 : KissColors.bg2),
            border: widget.filled
                ? null
                : Border.all(
                    color: _hover ? KissColors.strokeBright : KissColors.stroke,
                  ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: widget.filled && !disabled
                ? [
                    BoxShadow(
                      color: KissColors.pink.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 14,
                  color: widget.filled
                      ? Colors.white
                      : KissColors.textMid),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color:
                      widget.filled ? Colors.white : KissColors.textHi,
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
