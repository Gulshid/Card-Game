import '../models/game_state.dart';
import '../models/playing_card.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick_card.dart';
import 'card_tracker.dart';
import 'medium_ai.dart';
import 'play_analysis.dart';

/// Medium's heuristics plus:
///  * Nil bidding on very safe hands (the main source of its edge — in
///    simulation Nil alone lifts win rate from 50% to ~65% vs plain Medium);
///  * card counting: it leads "master" cards (nothing higher unseen) and
///    avoids winning with a card an unseen higher card or a known-void
///    opponent's trump could still beat.
///
/// Card tracking on its own measured only a small edge (~54% vs Medium
/// with identical bidding), so treat Nil as the headline difference.
class HardAi extends MediumAi {
  const HardAi() : super(allowNilBids: true);

  @override
  PlayingCard chooseLead(GameState state, Seat seat, List<PlayingCard> legal) {
    final int bid = state.bids[seat] ?? 0;
    if (bid == 0 || !PlayAnalysis.wantsMoreTricks(state, seat)) {
      return super.chooseLead(state, seat, legal);
    }

    final Set<PlayingCard> unseen = CardTracker.unseenCards(state, seat);
    final Set<(Seat, Suit)> voids = CardTracker.knownVoids(state);
    final List<Seat> opponents = Seat.values.where((s) => s.team != seat.team).toList();
    final bool spadesOut = unseen.any((c) => c.suit == Suit.spades);

    // A master side-suit card wins outright unless an opponent known to be
    // void in that suit can trump it.
    final List<PlayingCard> safeMasters = legal
        .where((c) => c.suit != Suit.spades)
        .where((c) => CardTracker.isMaster(c, unseen))
        .where((c) => !spadesOut || !opponents.any((o) => voids.contains((o, c.suit))))
        .toList();
    if (safeMasters.isNotEmpty) return PlayAnalysis.highest(safeMasters);

    final List<PlayingCard> masterSpades =
        legal.where((c) => c.suit == Suit.spades && CardTracker.isMaster(c, unseen)).toList();
    if (masterSpades.isNotEmpty) return PlayAnalysis.highest(masterSpades);

    return super.chooseLead(state, seat, legal);
  }

  @override
  PlayingCard chooseFollow(GameState state, Seat seat, List<PlayingCard> legal) {
    final TrickCard winner = PlayAnalysis.currentWinner(state.currentTrick);
    final List<PlayingCard> winning = legal.where((c) => PlayAnalysis.beats(c, winner.card)).toList();

    final int bid = state.bids[seat] ?? 0;
    final bool partnerWinning = winner.seat == seat.partner;
    final bool partnerNil = (state.bids[seat.partner] ?? 0) == 0;

    if (bid == 0 || partnerWinning || partnerNil || !PlayAnalysis.wantsMoreTricks(state, seat) || winning.isEmpty) {
      return super.chooseFollow(state, seat, legal);
    }

    final List<Seat> later = CardTracker.opponentsYetToPlay(state, seat);
    if (later.isEmpty) {
      // Last to play: the cheapest winner is guaranteed to hold.
      return PlayAnalysis.lowest(winning);
    }

    final Set<PlayingCard> unseen = CardTracker.unseenCards(state, seat);
    final Set<(Seat, Suit)> voids = CardTracker.knownVoids(state);
    final Suit led = state.currentTrick.first.card.suit;
    final bool spadesOut = unseen.any((c) => c.suit == Suit.spades);

    // Could a later opponent still take the trick away from [c]?
    bool isRisky(PlayingCard c) {
      for (final Seat opponent in later) {
        if (c.suit == Suit.spades) {
          final bool higherSpadeOut = unseen.any((u) => u.suit == Suit.spades && u.rank.value > c.rank.value);
          if (higherSpadeOut && !voids.contains((opponent, Suit.spades))) return true;
        } else if (voids.contains((opponent, led))) {
          if (spadesOut && !voids.contains((opponent, Suit.spades))) return true;
        } else if (unseen.any((u) => u.suit == c.suit && u.rank.value > c.rank.value)) {
          return true;
        }
      }
      return false;
    }

    final List<PlayingCard> safeWinners = winning.where((c) => !isRisky(c)).toList();
    if (safeWinners.isNotEmpty) return PlayAnalysis.lowest(safeWinners);
    // Nothing is safe: commit the strongest card to give the trick its best chance.
    return PlayAnalysis.highest(winning);
  }
}
