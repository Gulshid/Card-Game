import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short-lived burst of falling confetti particles, custom-painted —
/// no external package or image assets needed. Plays once on build and
/// leaves itself invisible (but still mounted) afterward; wrap it
/// behind other content with `IgnorePointer` since it never needs taps.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.particleCount = 60,
    this.duration = const Duration(milliseconds: 1600),
    this.colors = const [
      Color(0xFFD4A94F), // gold
      Color(0xFF6C93F0), // blue
      Color(0xFFF2D58B), // light gold
      Color(0xFF2FBF86), // green
      Colors.white,
    ],
  });

  final int particleCount;
  final Duration duration;
  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  _Particle(math.Random rng, List<Color> colors)
      : startX = rng.nextDouble(),
        driftX = (rng.nextDouble() - 0.5) * 0.5,
        fallDelay = rng.nextDouble() * 0.25,
        spinSpeed = (rng.nextDouble() - 0.5) * 10,
        size = 5 + rng.nextDouble() * 5,
        color = colors[rng.nextInt(colors.length)],
        isRect = rng.nextBool();

  final double startX;
  final double driftX;
  final double fallDelay;
  final double spinSpeed;
  final double size;
  final Color color;
  final bool isRect;
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Particle> _particles = List.generate(
    widget.particleCount,
    (_) => _Particle(math.Random(), widget.colors),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(particles: _particles, t: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final double localT = ((t - p.fallDelay) / (1 - p.fallDelay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final double y = size.height * localT;
      final double x = size.width * p.startX + size.width * p.driftX * localT;
      final double opacity = localT > 0.8 ? (1 - localT) * 5 : 1.0;
      if (opacity <= 0) continue;

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spinSpeed * localT);
      if (p.isRect) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
