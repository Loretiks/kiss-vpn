import 'package:flutter/material.dart';

import '../../core/mihomo/vpn_controller.dart';
import '../theme/tokens.dart';

/// Wide horizontal connect bar — modern VPN-client style (Mullvad / Proton).
///
///   * Resting (off):  solid pink→violet gradient, white text & icon
///   * Connecting:     amber pulsing background, spinner
///   * Connected:      success-green solid, glow shadow, "Отключить"
///   * Error:          danger-red outline
///
/// The bar is a fixed comfortable height (~64 px) and stretches up to ~440
/// px wide. Hover slightly lifts and brightens it; press shrinks 2%.
class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 0, // unused — kept for backwards-compat
    this.width = 420,
  });

  final VpnStatus status;
  final VoidCallback onTap;
  final double size;
  final double width;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  bool _hover = false;
  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _label => switch (widget.status) {
        VpnStatus.connected => 'Отключить',
        VpnStatus.connecting => 'Подключение…',
        VpnStatus.disconnecting => 'Отключение…',
        VpnStatus.error => 'Попробовать снова',
        VpnStatus.disconnected => 'Подключиться',
      };

  bool get _busy =>
      widget.status == VpnStatus.connecting ||
      widget.status == VpnStatus.disconnecting;

  @override
  Widget build(BuildContext context) {
    final connected = widget.status == VpnStatus.connected;
    final error = widget.status == VpnStatus.error;

    return RepaintBoundary(
      child: MouseRegion(
      cursor: _busy ? SystemMouseCursors.wait : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _busy ? null : widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final pulseT = 0.4 + 0.6 * _pulse.value;

            // Background & glow per state.
            Gradient? gradient;
            Color? solid;
            List<BoxShadow> shadow;
            Color borderColor = Colors.transparent;
            Color fg = Colors.white;

            if (connected) {
              solid = KissColors.success;
              shadow = [
                BoxShadow(
                  color: KissColors.success.withValues(alpha: 0.5 * pulseT),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ];
            } else if (error) {
              solid = Colors.transparent;
              borderColor = KissColors.danger;
              fg = KissColors.danger;
              shadow = const [];
            } else if (_busy) {
              gradient = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  KissColors.warning.withValues(alpha: 0.85 - 0.3 * pulseT),
                  KissColors.pink.withValues(alpha: 0.85 - 0.3 * pulseT),
                ],
              );
              shadow = [
                BoxShadow(
                  color: KissColors.warning.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ];
            } else {
              gradient = KissGradients.brand;
              shadow = [
                BoxShadow(
                  color: KissColors.pink.withValues(alpha: _hover ? 0.55 : 0.35),
                  blurRadius: _hover ? 30 : 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ];
            }

            final scale = _pressed ? 0.98 : (_hover ? 1.01 : 1.0);

            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: KissDurations.fast,
                width: widget.width,
                height: 64,
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: solid,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1.4),
                  boxShadow: shadow,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft top-edge highlight to fake material depth.
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 0.45],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          )
                        else
                          Icon(
                            connected
                                ? Icons.lock_rounded
                                : Icons.power_settings_new_rounded,
                            size: 22,
                            color: fg,
                          ),
                        const SizedBox(width: KissSpacing.md),
                        Text(
                          _label,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}
