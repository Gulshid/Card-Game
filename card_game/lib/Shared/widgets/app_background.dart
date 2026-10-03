import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen themed backdrop: a vertical gradient, a soft gold glow
/// and a barely-there scatter of card suits. Wrap a whole `Scaffold`
/// (with `backgroundColor: Colors.transparent`) in this.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key, this.showSuits = true});

  final Widget child;
  final bool showSuits;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ),
        ),
        // Warm glow, top-right.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, -0.95),
                  radius: 1.0,
                  colors: [
                    AppColors.gold.withValues(alpha: isDark ? 0.13 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Cool glow, bottom-left.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1.0, 1.0),
                  radius: 0.9,
                  colors: [
                    AppColors.blue.withValues(alpha: isDark ? 0.14 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showSuits)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(child: CustomPaint(painter: _SuitScatterPainter(isDark: isDark))),
            ),
          ),
        child,
      ],
    );
  }
}

class _SuitScatterPainter extends CustomPainter {
  _SuitScatterPainter({required this.isDark});

  final bool isDark;

  // x, y (0..1), size (fraction of width), rotation (rad), suit index
  static const List<(double, double, double, double, int)> _marks = [
    (0.10, 0.12, 0.20, -0.30, 2),
    (0.88, 0.30, 0.16, 0.35, 3),
    (0.18, 0.52, 0.14, 0.20, 1),
    (0.82, 0.74, 0.22, -0.25, 0),
    (0.30, 0.90, 0.15, 0.30, 3),
  ];
  static const List<String> _glyphs = ['♣', '♦', '♠', '♥'];

  @override
  void paint(Canvas canvas, Size size) {
    final Color ink = (isDark ? Colors.white : AppColors.navy).withValues(alpha: isDark ? 0.028 : 0.035);
    for (final (double x, double y, double s, double r, int suit) in _marks) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: _glyphs[suit], style: TextStyle(fontSize: size.width * s, color: ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.rotate(r);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SuitScatterPainter old) => old.isDark != isDark;
}
