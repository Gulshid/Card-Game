import 'dart:math' as math;

import '../models/playing_card.dart';
import '../models/rank.dart';
import '../models/suit.dart';

/// Pure hand-strength heuristics used for bidding. Only ever looks at a
/// single hand, so it is safe for any seat to call on its own cards.
abstract class HandEvaluator {
  /// Rough expected trick count for [hand].
  ///
  /// Spade honors and long spade holdings win tricks as trumps; side-suit
  /// Aces win outright, side-suit Kings need company; voids and
  /// singletons are worth a little when there are enough spades to ruff.
  static double estimateTricks(List<PlayingCard> hand) {
    final List<PlayingCard> spades = hand.where((c) => c.suit == Suit.spades).toList();
    final int spadeCount = spades.length;
    double estimate = 0;

    for (final PlayingCard card in spades) {
      if (card.rank == Rank.ace) {
        estimate += 1.0;
      } else if (card.rank == Rank.king) {
        estimate += spadeCount >= 2 ? 1.0 : 0.5;
      } else if (card.rank == Rank.queen) {
        estimate += spadeCount >= 3 ? 0.75 : 0.25;
      } else if (card.rank == Rank.jack) {
        estimate += spadeCount >= 4 ? 0.4 : 0.0;
      }
    }
    if (spadeCount > 3) {
      estimate += (spadeCount - 3) * 0.75;
    }

    for (final Suit suit in const [Suit.clubs, Suit.diamonds, Suit.hearts]) {
      final List<Rank> ranks = hand.where((c) => c.suit == suit).map((c) => c.rank).toList();
      final int length = ranks.length;
      if (ranks.contains(Rank.ace)) {
        estimate += 1.0;
      }
      if (ranks.contains(Rank.king)) {
        estimate += length >= 2 ? 0.6 : 0.1;
      }
      if (ranks.contains(Rank.queen) && ranks.contains(Rank.king) && length >= 3) {
        estimate += 0.3;
      }
      if (spadeCount >= 3) {
        if (length == 0) {
          estimate += 1.0;
        } else if (length == 1) {
          estimate += 0.5;
        }
      }
    }
    return estimate;
  }

  /// True when [hand] is a plausible Nil (zero-trick) hand: no Ace or
  /// King anywhere, no high spades, few spades, few face cards.
  static bool isNilSafe(List<PlayingCard> hand) {
    final int spadeCount = hand.where((c) => c.suit == Suit.spades).length;
    final int danger = hand.where((c) => c.rank.value >= 13).length +
        hand.where((c) => c.suit == Suit.spades && c.rank.value >= 9).length;
    final int faceCards = hand.where((c) => c.rank == Rank.jack || c.rank == Rank.queen).length;
    return danger == 0 && spadeCount <= 3 && faceCards <= 3;
  }

  /// The bid a bot would place: 0 (Nil) only when [allowNil] and the hand
  /// is Nil-safe, otherwise the rounded estimate clamped to 1..13.
  static int chooseBid(List<PlayingCard> hand, {required bool allowNil}) {
    if (allowNil && isNilSafe(hand)) {
      return 0;
    }
    return math.max(1, math.min(13, estimateTricks(hand).round()));
  }
}
