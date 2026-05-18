import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Pink-violet gradient heart drawn as a parametric path. Scales crisply
/// to any size and doesn't depend on bundled image assets.
class HeartLogo extends StatelessWidget {
  const HeartLogo({super.key, this.size = 28, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HeartPainter(glow: glow)),
    );
  }
}

class _HeartPainter extends CustomPainter {
  _HeartPainter({required this.glow});
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = _path(w, h);

    if (glow) {
      final glowPaint = Paint()
        ..color = KissColors.pink.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18);
      canvas.drawPath(path, glowPaint);
    }

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [KissColors.pink, KissColors.violet],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fill);

    // Subtle inner highlight on the upper-left lobe.
    final hl = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06);
    final inner = _path(w * 0.55, h * 0.55, dx: w * 0.13, dy: h * 0.10);
    canvas.drawPath(inner, hl);
  }

  Path _path(double w, double h, {double dx = 0, double dy = 0}) {
    final cx = dx + w / 2;
    final cy = dy + h / 2 + h * 0.07;
    final sx = w * 0.78 / 36;
    final sy = h * 0.78 / 36;
    final path = Path();
    for (var i = 0; i <= 360; i += 2) {
      final t = i * math.pi / 180;
      final x = 16 * math.pow(math.sin(t), 3).toDouble();
      final y = -(13 * math.cos(t) -
          5 * math.cos(2 * t) -
          2 * math.cos(3 * t) -
          math.cos(4 * t));
      final px = cx + x * sx;
      final py = cy + y * sy;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HeartPainter old) => old.glow != glow;
}
