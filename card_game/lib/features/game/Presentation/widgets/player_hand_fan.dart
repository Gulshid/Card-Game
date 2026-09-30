import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/hand_sorter.dart';
import 'playing_card_view.dart';

/// The human's own hand: a horizontal, overlapping fan of tappable
/// cards. Legal cards are full-opacity and lift slightly when tapped;
/// illegal ones are dimmed so the player can see their options at a
/// glance without reading the rules.
///
/// Tapping a legal card plays a brief "lift and release" animation —
/// the card scales up and starts fading — *before* [onCardTap] fires,
/// so there's a visible moment of the card leaving the player's hand
/// rather than it just vanishing the instant the cubit updates. Taps
/// are debounced while that animation is in flight.
class PlayerHandFan extends StatefulWidget {
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
  State<PlayerHandFan> createState() => _PlayerHandFanState();
}

class _PlayerHandFanState extends State<PlayerHandFan> {
  static const Duration _playOutDuration = Duration(milliseconds: 150);

  PlayingCard? _playingCard;

  Future<void> _handleTap(PlayingCard card) async {
    if (_playingCard != null) return; // debounce: one play-out at a time
    setState(() => _playingCard = card);
    await Future<void>.delayed(_playOutDuration);
    if (!mounted) return;
    widget.onCardTap(card);
    // If the card is still in hand after the callback (shouldn't
    // normally happen for a legal play, but guards against the cubit
    // rejecting it for some reason), release the lock so the hand
    // doesn't get stuck refusing taps.
    if (mounted) setState(() => _playingCard = null);
  }

  @override
  Widget build(BuildContext context) {
    final List<PlayingCard> sorted = HandSorter.sorted(widget.cards);
    final double overlap = widget.cardWidth.w * 0.62;

    return SizedBox(
      height: widget.cardWidth.w * 1.42 + 14.h,
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
                  padding: EdgeInsets.only(right: i == sorted.length - 1 ? 0 : (widget.cardWidth.w - overlap)),
                  child: _buildCard(sorted[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(PlayingCard card) {
    final bool isLegal = widget.isLegal(card);
    final bool tapEnabled = widget.enabled && isLegal && _playingCard == null;
    final bool isPlayingOut = _playingCard == card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tapEnabled ? () => _handleTap(card) : null,
      child: Semantics(
        button: true,
        enabled: tapEnabled,
        label: '$card',
        child: AnimatedScale(
          duration: _playOutDuration,
          scale: isPlayingOut ? 1.25 : 1.0,
          child: AnimatedOpacity(
            duration: _playOutDuration,
            opacity: isPlayingOut ? 0.0 : 1.0,
            child: PlayingCardView(
              card: card,
              width: widget.cardWidth,
              dimmed: !isLegal || !widget.enabled,
            ),
          ),
        ),
      ),
    );
  }
}
