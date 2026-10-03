import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'playing_card_view.dart';

/// The felt in the middle of the table: up to 4 played cards, each
/// positioned toward the seat that played it, resting on a soft circular
/// "play zone".
///
/// Once [winner] is set (the trick has resolved), the 4 cards animate:
/// they briefly glow and scale up in place, then — after a short pause
/// — sweep further toward the winner's side and fade out together,
/// reading as "the trick gets swept to whoever won it" rather than
/// just vanishing. `GameCubit`'s `trickPause` is what keeps this state
/// on screen long enough to see; this widget only animates within that
/// window, it doesn't control the timing itself.
class TrickArea extends StatelessWidget {
  const TrickArea({
    required this.trick,
    super.key,
    this.winner,
  });

  final List<TrickCard> trick;
  final Seat? winner;

  static const Map<Seat, Alignment> _alignment = {
    Seat.north: Alignment(0, -0.7),
    Seat.east: Alignment(0.7, 0),
    Seat.south: Alignment(0, 0.7),
    Seat.west: Alignment(-0.7, 0),
  };

  /// Where a card sweeps to once the trick is won — further out toward
  /// the winner's seat than any card's normal resting position, so the
  /// motion reads as "collected," not just "shifted."
  static const Map<Seat, Alignment> _sweepTarget = {
    Seat.north: Alignment(0, -1.6),
    Seat.east: Alignment(1.6, 0),
    Seat.south: Alignment(0, 1.6),
    Seat.west: Alignment(-1.6, 0),
  };

  /// A slight, fixed tilt per seat so the pile looks tossed, not gridded.
  static const Map<Seat, double> _tilt = {
    Seat.north: -0.05,
    Seat.east: 0.09,
    Seat.south: 0.03,
    Seat.west: -0.08,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160.w,
      height: 160.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Play zone.
          Container(
            width: 146.w,
            height: 146.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.22)],
              ),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.16), width: 1.2),
            ),
          ),
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          if (trick.isEmpty)
            Text('♠', style: TextStyle(fontSize: 46.sp, color: Colors.white.withValues(alpha: 0.07))),
          for (final TrickCard tc in trick)
            _AnimatedTrickCard(
              key: ValueKey('${tc.seat}-${tc.card}'),
              trickCard: tc,
              restingAlignment: _alignment[tc.seat]!,
              sweepAlignment: winner == null ? null : _sweepTarget[winner]!,
              isWinner: winner == tc.seat,
              tilt: _tilt[tc.seat]!,
            ),
        ],
      ),
    );
  }
}

class _AnimatedTrickCard extends StatelessWidget {
  const _AnimatedTrickCard({
    required this.trickCard,
    required this.restingAlignment,
    required this.sweepAlignment,
    required this.isWinner,
    required this.tilt,
    super.key,
  });

  final TrickCard trickCard;
  final Alignment restingAlignment;
  final Alignment? sweepAlignment;
  final bool isWinner;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final bool sweeping = sweepAlignment != null;

    return AnimatedAlign(
      duration: Duration(milliseconds: sweeping ? 380 : 220),
      curve: sweeping ? Curves.easeIn : Curves.easeOut,
      alignment: sweeping ? sweepAlignment! : restingAlignment,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: sweeping ? 380 : 220),
        curve: Curves.easeIn,
        opacity: sweeping ? 0.0 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: isWinner && !sweeping ? 1.12 : 1.0,
          child: Transform.rotate(
            angle: tilt,
            child: Container(
              decoration: isWinner && !sweeping
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.85), blurRadius: 18, spreadRadius: 1),
                      ],
                    )
                  : null,
              child: PlayingCardView(card: trickCard.card, width: 42),
            ),
          ),
        ),
      ),
    );
  }
}
