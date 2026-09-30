import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps a face-down and a face-up widget (typically two
/// `PlayingCardView`s) and animates a 3D flip between them around the
/// vertical axis, like a card turning over on a table. Used by
/// [DealAnimationOverlay] to reveal the human's hand as it lands, and
/// reusable anywhere else a card needs to visibly "turn over" (e.g. a
/// future reveal-the-table moment at match end).
class FlippableCard extends StatefulWidget {
  const FlippableCard({
    required this.faceDown,
    required this.faceUp,
    required this.showFace,
    super.key,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget faceDown;
  final Widget faceUp;

  /// Flips to [faceUp] when this becomes true; flips back if it becomes
  /// false again.
  final bool showFace;
  final Duration duration;

  @override
  State<FlippableCard> createState() => _FlippableCardState();
}

class _FlippableCardState extends State<FlippableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.showFace) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant FlippableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFace != oldWidget.showFace) {
      if (widget.showFace) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 0 -> 0.5 shows the back (rotating in); 0.5 -> 1 shows the
        // front (rotating out), so the visible face swaps exactly at
        // the midpoint, when the card is edge-on and invisible anyway.
        final double t = _controller.value;
        final bool showingFront = t > 0.5;
        final double angle = t * math.pi;

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: showingFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.faceUp,
                )
              : widget.faceDown,
        );
      },
    );
  }
}
