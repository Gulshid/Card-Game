import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'playing_card_view.dart';

/// A small face-down fan representing an opponent's remaining hand,
/// oriented for the seat's position around the table (vertical stacks
/// for East/West, horizontal for North).
class OpponentHandView extends StatelessWidget {
  const OpponentHandView({
    required this.cardCount,
    super.key,
    this.vertical = false,
    this.cardWidth = 30,
    this.isThinking = false,
  });

  final int cardCount;
  final bool vertical;
  final double cardWidth;
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    final int shown = cardCount.clamp(0, 13);
    final double overlap = cardWidth.w * 0.55;

    final List<Widget> cards = [
      for (int i = 0; i < shown; i++)
        Padding(
          padding: vertical
              ? EdgeInsets.only(bottom: i == shown - 1 ? 0 : (cardWidth.w * 1.42 - overlap))
              : EdgeInsets.only(right: i == shown - 1 ? 0 : (cardWidth.w - overlap)),
          child: PlayingCardView(card: null, faceDown: true, width: cardWidth),
        ),
    ];

    final Widget fan = vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: cards)
        : Row(mainAxisSize: MainAxisSize.min, children: cards);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isThinking ? 0.75 : 1.0,
      child: fan,
    );
  }
}
