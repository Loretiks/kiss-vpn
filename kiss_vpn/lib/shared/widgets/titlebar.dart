import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/mihomo/vpn_controller.dart';
import '../../core/storage/settings.dart';
import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';
import 'heart_logo.dart';

/// Custom frameless-window titlebar.
class Titlebar extends ConsumerWidget {
  const Titlebar({super.key, this.pinned = false, this.onPin});

  final bool pinned;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closeToTray = ref.watch(settingsControllerProvider).closeToTray;
    return SizedBox(
      height: 44,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        onDoubleTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: Row(
          children: [
            const SizedBox(width: KissSpacing.lg),
            _BrandWordmark(),
            Expanded(
              child: Container(color: const Color(0x01000000)),
            ),
            _IconBtn(
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              tooltip: pinned ? 'Открепить' : 'Поверх всех окон',
              onTap: onPin,
            ),
            _IconBtn(
              icon: Icons.remove,
              tooltip: 'Свернуть',
              onTap: () => windowManager.minimize(),
            ),
            _IconBtn(
              icon: Icons.crop_square_outlined,
              tooltip: 'Развернуть',
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _IconBtn(
              icon: Icons.close,
              tooltip: closeToTray ? 'Скрыть в трей' : 'Закрыть',
              danger: true,
              onTap: () {
                if (closeToTray) {
                  windowManager.hide();
                } else {
                  ref.read(vpnControllerProvider.notifier).disconnect();
                  windowManager.destroy();
                }
              },
            ),
            const SizedBox(width: KissSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heart-shaped brand mark. Drawn via CustomPaint so it stays
        // crisp at any DPI and doesn't depend on an asset round-trip.
        const SizedBox(
          width: 28,
          height: 28,
          child: HeartLogo(size: 26, glow: true),
        ),
        const SizedBox(width: KissSpacing.md),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'kiss',
                style: TextStyle(
                  fontFamily: 'Unbounded',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: t.textHi,
                  letterSpacing: -0.2,
                ),
              ),
              TextSpan(
                text: '  VPN',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: t.textLow,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final t = KissTheme.of(context);
    final color = _hover
        ? (widget.danger ? t.danger : t.textHi)
        : t.textMid;
    final bg = _hover
        ? (widget.danger
            ? t.danger.withValues(alpha: 0.12)
            : t.bg3)
        : Colors.transparent;

    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: KissDurations.fast,
          width: 36,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 15, color: color),
        ),
      ),
    );
    return widget.tooltip == null
        ? btn
        : Tooltip(message: widget.tooltip!, child: btn);
  }
}
