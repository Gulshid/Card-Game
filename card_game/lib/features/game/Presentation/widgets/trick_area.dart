import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'playing_card_view.dart';

/// The felt in the middle of the table: up to 4 played cards, each
/// positioned toward the seat that played it, with the trick's winner
/// (once resolved) briefly highlighted with a glow.
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150.w,
      height: 150.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final TrickCard tc in trick)
            AnimatedAlign(
              key: ValueKey('${tc.seat}-${tc.card}'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: _alignment[tc.seat]!,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: winner == tc.seat ? 1.12 : 1.0,
                child: Container(
                  decoration: winner == tc.seat
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          boxShadow: const [BoxShadow(color: Color(0xFFC79A3D), blurRadius: 16, spreadRadius: 1)],
                        )
                      : null,
                  child: PlayingCardView(card: tc.card, width: 42),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
