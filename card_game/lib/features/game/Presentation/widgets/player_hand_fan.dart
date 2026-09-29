import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/hand_sorter.dart';
import 'playing_card_view.dart';

/// The human's own hand: a horizontal, overlapping fan of tappable
/// cards. Legal cards are full-opacity and lift slightly when tapped;
/// illegal ones are dimmed so the player can see their options at a
/// glance without reading the rules.
class PlayerHandFan extends StatelessWidget {
  const PlayerHandFan({
    required this.cards,
    required this.isLegal,
    required this.onCardTap,
    super.key,
    this.enabled = true,
    this.cardWidth = 46,
  });

  final List<PlayingCard> cards;
  final bool Function(PlayingCard card) isLegal;
  final ValueChanged<PlayingCard> onCardTap;
  final bool enabled;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final List<PlayingCard> sorted = HandSorter.sorted(cards);
    final double overlap = cardWidth.w * 0.62;

    return SizedBox(
      height: cardWidth.w * 1.42 + 14.h,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < sorted.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == sorted.length - 1 ? 0 : (cardWidth.w - overlap)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled && isLegal(sorted[i]) ? () => onCardTap(sorted[i]) : null,
                    child: Semantics(
                      button: true,
                      enabled: enabled && isLegal(sorted[i]),
                      label: '${sorted[i]}',
                      child: PlayingCardView(
                        card: sorted[i],
                        width: cardWidth,
                        dimmed: !isLegal(sorted[i]) || !enabled,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
