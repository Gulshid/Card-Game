import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:flutter/material.dart';

import '../utils/hand_sorter.dart';
import 'flippable_card.dart';
import 'playing_card_view.dart';

/// Plays once, on mount: a handful of cards fly from the center of the
/// table out toward each of the four seats, staggered, then the whole
/// thing fades away and [onComplete] fires.
///
/// The cards flying toward South (the human) carry [humanCards] and
/// flip face-up with [FlippableCard] right as they land — so the
/// player actually sees a few of their real cards revealed, not just
/// generic card backs. North/East/West always stay face-down, since
/// the player never sees an opponent's hand.
///
/// Give this widget a fresh `Key` (e.g. `ValueKey(roundNumber)`) every
/// time a new round is dealt so Flutter tears down the old animation
/// and builds a new one from scratch rather than trying to reuse state
/// across two different deals.
class DealAnimationOverlay extends StatefulWidget {
  const DealAnimationOverlay({
    required this.onComplete,
    super.key,
    this.humanCards = const [],
  });

  final VoidCallback onComplete;
  final List<PlayingCard> humanCards;

  @override
  State<DealAnimationOverlay> createState() => _DealAnimationOverlayState();
}

const List<Alignment> _targets = [
  Alignment(0, -0.75), // north
  Alignment(0.85, 0), // east
  Alignment(0, 0.75), // south (human)
  Alignment(-0.85, 0), // west
];
const int _southDirectionIndex = 2;
const int _cardsPerDirection = 3;

class _DealAnimationOverlayState extends State<DealAnimationOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();
  late final List<PlayingCard> _revealCards = HandSorter.sorted(widget.humanCards).take(_cardsPerDirection).toList();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
  }

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
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int direction = 0; direction < _targets.length; direction++)
                for (int card = 0; card < _cardsPerDirection; card++) _flight(direction, card),
            ],
          );
        },
      ),
    );
  }

  Widget _flight(int direction, int cardIndex) {
    // Stagger: each direction starts slightly after the previous, and
    // within a direction each of the 3 cards follows the last.
    final double start = (direction * 0.08 + cardIndex * 0.06).clamp(0.0, 0.7);
    final double end = (start + 0.35).clamp(0.0, 1.0);
    final CurvedAnimation curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final double flightT = curve.value;
    if (flightT <= 0) return const SizedBox.shrink();

    final Alignment target = _targets[direction];
    final Alignment current = Alignment.lerp(Alignment.center, target, flightT)!;
    const double fadeOutStart = 0.75;
    final double opacity = _controller.value < fadeOutStart
        ? 1.0
        : (1 - (_controller.value - fadeOutStart) / (1 - fadeOutStart)).clamp(0.0, 1.0);

    final bool isSouth = direction == _southDirectionIndex;
    final bool hasRevealCard = isSouth && cardIndex < _revealCards.length;
    // Flip to the real face once the card is most of the way to its seat.
    final bool showFace = hasRevealCard && flightT > 0.7;

    final Widget card = hasRevealCard
        ? FlippableCard(
            faceDown: const PlayingCardView(card: null, faceDown: true, width: 26),
            faceUp: PlayingCardView(card: _revealCards[cardIndex], width: 26),
            showFace: showFace,
            duration: const Duration(milliseconds: 180),
          )
        : const PlayingCardView(card: null, faceDown: true, width: 22);

    return Align(
      alignment: current,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(angle: flightT * 2.2, child: card),
      ),
    );
  }
}
