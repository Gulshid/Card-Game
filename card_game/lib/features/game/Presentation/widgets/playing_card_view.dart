import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Renders one physical card — either its face ([card]) or, when
/// [faceDown] is true, a plain back. Used for the human's hand, the
/// trick area, and opponents' face-down fans alike, so every card in
/// the app looks and sizes identically.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.card,
    super.key,
    this.faceDown = false,
    this.width = 44,
    this.selected = false,
    this.dimmed = false,
  });

  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final bool selected;

  /// Rendered at reduced opacity — used for a currently-illegal card in
  /// the human's hand, so the legal plays visually stand out.
  final bool dimmed;

  static const double _aspectRatio = 1.42; // height / width

  @override
  Widget build(BuildContext context) {
    final double w = width.w;
    final double h = w * _aspectRatio;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: dimmed ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: w,
        height: h,
        transform: selected ? (Matrix4.identity()..translate(0.0, -10.0.h)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: faceDown ? const Color(0xFF2451B5) : Colors.white,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: selected ? const Color(0xFFC79A3D) : Colors.black.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.35 : 0.2),
              blurRadius: selected ? 8 : 3,
              offset: Offset(0, selected ? 4 : 1.5),
            ),
          ],
        ),
        child: faceDown ? _buildBack() : _buildFace(w),
      ),
    );
  }

  Widget _buildBack() {
    return Center(
      child: Icon(Icons.style_outlined, color: Colors.white.withValues(alpha: 0.5), size: width.w * 0.5),
    );
  }

  Widget _buildFace(double w) {
    final PlayingCard c = card!;
    final Color suitColor = c.suit.isRed ? const Color(0xFFD85A30) : const Color(0xFF12213B);
    final double fontSize = w * 0.30;

    return Padding(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.rank.label,
            style: TextStyle(color: suitColor, fontSize: fontSize, fontWeight: FontWeight.w700, height: 1),
          ),
          Text(c.suit.symbol, style: TextStyle(color: suitColor, fontSize: fontSize * 0.85, height: 1)),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              c.suit.symbol,
              style: TextStyle(color: suitColor, fontSize: fontSize * 1.3, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
