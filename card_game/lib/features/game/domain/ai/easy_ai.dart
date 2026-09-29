import 'dart:math' as math;

import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/playing_card.dart';
import '../models/seat.dart';
import 'ai_strategy.dart';
import 'hand_evaluator.dart';
import 'play_analysis.dart';

/// Plays any legal card at random. Bids one trick under its hand's
/// estimate (sometimes two) so a team of Easy bots makes its bids often
/// enough for matches to finish in a sensible number of rounds.
class EasyAi implements AiStrategy {
  EasyAi({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  @override
  Move chooseMove(GameState state) {
    final Seat seat = state.turn;

    if (state.phase == GamePhase.bidding) {
      final double estimate = HandEvaluator.estimateTricks(state.hands[seat] ?? const <PlayingCard>[]);
      final int bid = math.max(1, math.min(13, estimate.round() - 1 + _random.nextInt(2)));
      return BidMove(seat: seat, tricksBid: bid);
    }

    if (state.phase == GamePhase.playing) {
      final List<PlayingCard> legal = PlayAnalysis.legalCards(state, seat);
      return PlayCardMove(seat: seat, card: legal[_random.nextInt(legal.length)]);
    }

    throw StateError('EasyAi asked to move in phase ${state.phase}');
  }
}
