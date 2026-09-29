import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/playing_card.dart';
import '../models/rank.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick_card.dart';
import 'ai_strategy.dart';
import 'hand_evaluator.dart';
import 'play_analysis.dart';

/// Heuristic bot. Bids from a hand-strength estimate, then plays to make
/// exactly its team's bid: it takes tricks cheaply while the team still
/// needs them, and ducks (to avoid bags) once the bid is safe.
///
/// [chooseLead] and [chooseFollow] are public so [HardAi] can specialise
/// them while inheriting everything else.
class MediumAi implements AiStrategy {
  const MediumAi({this.allowNilBids = false});

  /// Whether this bot may bid Nil on a very safe hand.
  final bool allowNilBids;

  @override
  Move chooseMove(GameState state) {
    final Seat seat = state.turn;

    if (state.phase == GamePhase.bidding) {
      final int bid = HandEvaluator.chooseBid(
        state.hands[seat] ?? const <PlayingCard>[],
        allowNil: allowNilBids,
      );
      return BidMove(seat: seat, tricksBid: bid);
    }

    if (state.phase == GamePhase.playing) {
      final List<PlayingCard> legal = PlayAnalysis.legalCards(state, seat);
      final PlayingCard card = state.currentTrick.isEmpty
          ? chooseLead(state, seat, legal)
          : chooseFollow(state, seat, legal);
      return PlayCardMove(seat: seat, card: card);
    }

    throw StateError('$runtimeType asked to move in phase ${state.phase}');
  }

  /// Choose a card to open a trick.
  PlayingCard chooseLead(GameState state, Seat seat, List<PlayingCard> legal) {
    final int bid = state.bids[seat] ?? 0;
    final List<PlayingCard> nonSpades = legal.where((c) => c.suit != Suit.spades).toList();

    if (bid == 0) {
      return PlayAnalysis.dumpLowest(legal);
    }
    if (PlayAnalysis.wantsMoreTricks(state, seat)) {
      final List<PlayingCard> aces = nonSpades.where((c) => c.rank == Rank.ace).toList();
      if (aces.isNotEmpty) return aces.first;
      if (nonSpades.isNotEmpty) return PlayAnalysis.highest(nonSpades);
      return PlayAnalysis.highest(legal);
    }
    return nonSpades.isNotEmpty ? PlayAnalysis.lowest(nonSpades) : PlayAnalysis.lowest(legal);
  }

  /// Choose a card when following someone else's lead.
  PlayingCard chooseFollow(GameState state, Seat seat, List<PlayingCard> legal) {
    final TrickCard winner = PlayAnalysis.currentWinner(state.currentTrick);
    final List<PlayingCard> winning = legal.where((c) => PlayAnalysis.beats(c, winner.card)).toList();
    final List<PlayingCard> losing = legal.where((c) => !PlayAnalysis.beats(c, winner.card)).toList();

    final int bid = state.bids[seat] ?? 0;
    final Seat partner = seat.partner;
    final bool partnerWinning = winner.seat == partner;

    // Own Nil: get rid of the highest card that still loses the trick.
    if (bid == 0) {
      return losing.isNotEmpty ? PlayAnalysis.highest(losing) : PlayAnalysis.lowest(legal);
    }
    // Partner's Nil is in danger: take the trick ourselves, as cheaply as possible.
    if ((state.bids[partner] ?? 0) == 0 && partnerWinning && winning.isNotEmpty) {
      return PlayAnalysis.lowest(winning);
    }
    // Partner is already winning: don't overtake, just throw a low card.
    if (partnerWinning) {
      return PlayAnalysis.dumpLowest(legal);
    }
    // An opponent is winning and we still need tricks: win as cheaply as possible.
    if (PlayAnalysis.wantsMoreTricks(state, seat) && winning.isNotEmpty) {
      return PlayAnalysis.lowest(winning);
    }
    return PlayAnalysis.dumpLowest(legal);
  }
}
