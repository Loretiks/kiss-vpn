import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';

/// Soft pink + violet aurora gradient mesh used as a full-page backdrop.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, this.child, this.intensity = 1.0});

  final Widget? child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    // The mesh layer is fully static — rasterise it once into its own
    // layer with RepaintBoundary so a child repaint (e.g. the spinning
    // connect ring) doesn't re-paint these three Gaussian blobs, which
    // are *expensive* per frame on the CPU rasteriser.
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: t.bg0),
              _GlowBlob(
                alignment: const Alignment(-1.15, -0.95),
                color: t.accent.withValues(alpha: 0.45 * intensity),
                radius: 1.0,
              ),
              _GlowBlob(
                alignment: const Alignment(1.25, -0.6),
                color: t.accentAlt.withValues(alpha: 0.40 * intensity),
                radius: 1.1,
              ),
              _GlowBlob(
                alignment: const Alignment(0.9, 1.2),
                color: t.accentDeep.withValues(alpha: 0.28 * intensity),
                radius: 1.3,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.3,
                    colors: [
                      Colors.transparent,
                      t.bg0.withValues(alpha: 0.55),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.color,
    required this.radius,
  });

  final Alignment alignment;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: radius,
        heightFactor: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.0)],
              stops: const [0.0, 0.8],
            ),
          ),
        ),
      ),
    );
  }
}
