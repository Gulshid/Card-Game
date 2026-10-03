import 'dart:math' as math;

import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/Profile/presentation/cosmetic_theme.dart';
import 'package:card_game/features/Profile/presentation/widgets/card_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders one physical card — either its face ([card]) or, when
/// [faceDown] is true, the player's chosen back. Used for the human's
/// hand, the trick area, and opponents' face-down fans alike, so every
/// card in the app looks and sizes identically.
///
/// Face: ivory stock, corner indices (mirrored top-left / bottom-right),
/// a large centre pip, and a framed court-card panel for J/Q/K.
/// Back: a two-tone gradient with an inset border, a diamond lattice and
/// a centre medallion carrying the style's icon.
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    required this.card,
    super.key,
    this.faceDown = false,
    this.width = 44,
    this.selected = false,
    this.dimmed = false,
    this.highlight = false,
  });

  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final bool selected;

  /// Rendered at reduced opacity — used for a currently-illegal card in
  /// the human's hand, so the legal plays visually stand out.
  final bool dimmed;

  /// A thin gold edge — marks a card the player can legally play now.
  final bool highlight;

  static const double _aspectRatio = 1.42; // height / width

  @override
  Widget build(BuildContext context) {
    final double w = width.w;
    final double h = w * _aspectRatio;
    final double radius = w * 0.13;
    // The back the player picked on the Profile screen; the classic blue
    // when there is no CardBackScope above (tests, UI kit).
    final CardBackStyle back = CardBackScope.of(context);

    final bool emphasised = selected || highlight;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: dimmed ? 0.5 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: w,
        height: h,
        transform: selected ? Matrix4.translationValues(0, -10.h, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: faceDown
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(back.base, Colors.white, 0.16)!,
                    Color.lerp(back.base, Colors.black, 0.38)!,
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFEEF0F6)],
                ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: emphasised
                ? AppColors.gold
                : (faceDown ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.14)),
            width: selected ? 2 : (highlight ? 1.4 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.45 : 0.28),
              blurRadius: selected ? 12 : 4,
              offset: Offset(0, selected ? 6 : 2),
            ),
            if (highlight && !selected)
              BoxShadow(color: AppColors.gold.withValues(alpha: 0.28), blurRadius: 8),
          ],
        ),
        child: faceDown ? _buildBack(back, w, radius) : _buildFace(w),
      ),
    );
  }

  // ---- Back ---------------------------------------------------------------

  Widget _buildBack(CardBackStyle back, double w, double radius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BackPatternPainter(accent: back.accent)),
          Center(
            child: Container(
              width: w * 0.5,
              height: w * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(back.base, Colors.black, 0.25),
                border: Border.all(color: back.accent.withValues(alpha: 0.75), width: 1),
              ),
              child: Icon(back.icon, color: back.accent, size: w * 0.28),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Face ---------------------------------------------------------------

  Widget _buildFace(double w) {
    final PlayingCard c = card!;
    final Color ink = c.suit.isRed ? AppColors.suitRed : AppColors.suitBlack;
    final bool isCourt = c.rank == Rank.jack || c.rank == Rank.queen || c.rank == Rank.king;
    final bool isAce = c.rank == Rank.ace;
    final double idx = w * 0.28;

    final Widget corner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.rank.label,
          style: GoogleFonts.manrope(
            color: ink,
            fontSize: idx,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: c.rank == Rank.ten ? -1.2 : 0,
          ),
        ),
        Text(c.suit.symbol, style: TextStyle(color: ink, fontSize: idx * 0.85, height: 1)),
      ],
    );

    final Widget centre = isCourt
        ? Container(
            width: w * 0.52,
            height: w * 0.70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(w * 0.08),
              border: Border.all(color: ink.withValues(alpha: 0.30), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.rank.label,
                  style: GoogleFonts.playfairDisplay(
                    color: ink,
                    fontSize: w * 0.30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(c.suit.symbol, style: TextStyle(color: ink, fontSize: w * 0.24, height: 1)),
              ],
            ),
          )
        : Text(
            c.suit.symbol,
            style: TextStyle(color: ink, fontSize: isAce ? w * 0.64 : w * 0.48, height: 1),
          );

    return Stack(
      children: [
        Positioned(left: w * 0.08, top: w * 0.06, child: corner),
        if (w >= 34)
          Positioned(
            right: w * 0.08,
            bottom: w * 0.06,
            child: Transform.rotate(angle: math.pi, child: corner),
          ),
        Align(alignment: const Alignment(0, 0.08), child: centre),
      ],
    );
  }
}

/// Inset border + diamond lattice for card backs.
class _BackPatternPainter extends CustomPainter {
  _BackPatternPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = size.width * 0.075;
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      Radius.circular(size.width * 0.07),
    );

    canvas.save();
    canvas.clipRRect(inner);
    final Paint lattice = Paint()
      ..color = accent.withValues(alpha: 0.17)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final double step = math.max(5.0, size.width * 0.17);
    for (double k = -size.height; k < size.width + size.height; k += step) {
      canvas.drawLine(Offset(k, 0), Offset(k + size.height, size.height), lattice);
      canvas.drawLine(Offset(k, size.height), Offset(k + size.height, 0), lattice);
    }
    canvas.restore();

    canvas.drawRRect(
      inner,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _BackPatternPainter old) => old.accent != accent;
}
