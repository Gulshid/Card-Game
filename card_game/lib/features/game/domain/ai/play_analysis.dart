import '../engine/spades_rules_engine.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/playing_card.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick_card.dart';

/// Small pure helpers shared by every bot strategy.
abstract class PlayAnalysis {
  /// Cards in [seat]'s hand that are legal to play right now.
  static List<PlayingCard> legalCards(GameState state, Seat seat) {
    final List<PlayingCard> hand = state.hands[seat] ?? const [];
    return hand
        .where((c) => SpadesRulesEngine.isValidMove(state, PlayCardMove(seat: seat, card: c)))
        .toList();
  }

  /// Who is currently winning [trick] (which must be non-empty): the
  /// highest spade if any spade is down, otherwise the highest card of
  /// the led suit.
  static TrickCard currentWinner(List<TrickCard> trick) {
    final Suit led = trick.first.card.suit;
    final bool anySpade = trick.any((t) => t.card.suit == Suit.spades);
    final Suit winningSuit = anySpade ? Suit.spades : led;
    TrickCard best = trick.firstWhere((t) => t.card.suit == winningSuit);
    for (final TrickCard t in trick) {
      if (t.card.suit == winningSuit && t.card.rank.value > best.card.rank.value) {
        best = t;
      }
    }
    return best;
  }

  /// Whether playing [card] would take the lead from [winner].
  static bool beats(PlayingCard card, PlayingCard winner) {
    if (card.suit == winner.suit) {
      return card.rank.value > winner.rank.value;
    }
    return card.suit == Suit.spades;
  }

  /// A team's trick target: the sum of its members' non-Nil bids.
  static int teamBidTarget(GameState state, int team) {
    int target = 0;
    for (final Seat seat in Seat.values) {
      if (seat.team != team) continue;
      final int bid = state.bids[seat] ?? 0;
      if (bid > 0) target += bid;
    }
    return target;
  }

  /// True while [seat]'s team still needs tricks to make its bid. A Nil
  /// bidder never wants tricks.
  static bool wantsMoreTricks(GameState state, Seat seat) {
    if ((state.bids[seat] ?? 0) == 0) return false;
    return state.tricksWonByTeam(seat.team) < teamBidTarget(state, seat.team);
  }

  /// Lowest-ranked card; the first one wins ties.
  static PlayingCard lowest(List<PlayingCard> cards) {
    return cards.reduce((a, b) => b.rank.value < a.rank.value ? b : a);
  }

  /// Highest-ranked card; the first one wins ties.
  static PlayingCard highest(List<PlayingCard> cards) {
    return cards.reduce((a, b) => b.rank.value > a.rank.value ? b : a);
  }

  /// The cheapest card to throw away: lowest non-spade if there is one
  /// (spades are trumps worth keeping), otherwise the lowest spade.
  static PlayingCard dumpLowest(List<PlayingCard> cards) {
    int key(PlayingCard c) => (c.suit == Suit.spades ? 100 : 0) + c.rank.value;
    return cards.reduce((a, b) => key(b) < key(a) ? b : a);
  }
}
