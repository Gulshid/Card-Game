import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A hand-drawn spade, painted with a [Path] so it looks identical on
/// every platform (font glyphs for ♠ vary a lot between devices).
class SpadeMark extends StatelessWidget {
  const SpadeMark({super.key, this.size = 48, this.color, this.gradient});

  final double size;

  /// Solid fill. Ignored when [gradient] is set.
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SpadePainter(color: color ?? AppColors.gold, gradient: gradient)),
    );
  }
}

class _SpadePainter extends CustomPainter {
  _SpadePainter({required this.color, this.gradient});

  final Color color;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Path p = Path()
      ..moveTo(w * 0.5, 0)
      ..cubicTo(w * 0.5, h * 0.18, w * 1.02, h * 0.30, w * 0.95, h * 0.56)
      ..cubicTo(w * 0.90, h * 0.80, w * 0.60, h * 0.78, w * 0.54, h * 0.64)
      ..cubicTo(w * 0.55, h * 0.82, w * 0.62, h * 0.92, w * 0.72, h)
      ..lineTo(w * 0.28, h)
      ..cubicTo(w * 0.38, h * 0.92, w * 0.45, h * 0.82, w * 0.46, h * 0.64)
      ..cubicTo(w * 0.40, h * 0.78, w * 0.10, h * 0.80, w * 0.05, h * 0.56)
      ..cubicTo(w * -0.02, h * 0.30, w * 0.5, h * 0.18, w * 0.5, 0)
      ..close();

    final Paint paint = Paint()..isAntiAlias = true;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Offset.zero & size);
    } else {
      paint.color = color;
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _SpadePainter old) => old.color != color || old.gradient != gradient;
}

/// The app emblem: a spade on a dark disc with a gold ring and soft glow.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 88, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF1F3366), Color(0xFF0C1630)],
        ),
        border: Border.all(color: AppColors.gold, width: size * 0.022),
        boxShadow: glow
            ? [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: size * 0.45, spreadRadius: 1),
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: size * 0.2, offset: Offset(0, size * 0.08)),
              ]
            : null,
      ),
      child: SpadeMark(size: size * 0.46, gradient: AppColors.goldGradient),
    );
  }
}
