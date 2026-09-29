import '../models/deck.dart';
import '../models/game_state.dart';
import '../models/playing_card.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick_card.dart';

/// Card-counting helpers built purely from public information plus the
/// acting seat's own hand — never from another seat's hand.
abstract class CardTracker {
  /// Every card already played this round (finished tricks + current).
  static Set<PlayingCard> playedCards(GameState state) {
    return {
      for (final List<TrickCard> trick in state.completedTricks)
        for (final TrickCard tc in trick) tc.card,
      for (final TrickCard tc in state.currentTrick) tc.card,
    };
  }

  /// Cards that are neither played nor in [seat]'s own hand, i.e. the
  /// cards held by the other three players.
  static Set<PlayingCard> unseenCards(GameState state, Seat seat) {
    final Set<PlayingCard> seen = {
      ...playedCards(state),
      ...(state.hands[seat] ?? const <PlayingCard>[]),
    };
    return Deck.standard52().cards.where((c) => !seen.contains(c)).toSet();
  }

  /// True when no unseen card of the same suit outranks [card].
  static bool isMaster(PlayingCard card, Set<PlayingCard> unseen) {
    return !unseen.any((c) => c.suit == card.suit && c.rank.value > card.rank.value);
  }

  /// (seat, suit) pairs where the seat has already failed to follow that
  /// suit, proving it holds none of it.
  static Set<(Seat, Suit)> knownVoids(GameState state) {
    final Set<(Seat, Suit)> voids = <(Seat, Suit)>{};
    void scan(List<TrickCard> trick) {
      if (trick.isEmpty) return;
      final Suit led = trick.first.card.suit;
      for (final TrickCard tc in trick) {
        if (tc.card.suit != led) {
          voids.add((tc.seat, led));
        }
      }
    }

    for (final List<TrickCard> trick in state.completedTricks) {
      scan(trick);
    }
    scan(state.currentTrick);
    return voids;
  }

  /// Opponents of [seat] who have not yet played to the current trick.
  static List<Seat> opponentsYetToPlay(GameState state, Seat seat) {
    final Set<Seat> played = state.currentTrick.map((t) => t.seat).toSet();
    return Seat.values.where((s) => s.team != seat.team && s != seat && !played.contains(s)).toList();
  }
}
