import 'dart:math';

import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import 'spades_rules_engine.dart';

/// Picks a uniformly random *legal* move for whoever's turn it is.
/// Deliberately reusable beyond testing: Phase 06's Easy bot is
/// exactly this function wired into the UI's turn loop, so the
/// "random legal move" behavior only has to be correct once.
Move chooseRandomLegalMove(GameState state, Random rng) {
  final List<Move> candidates = switch (state.phase) {
    GamePhase.bidding => [for (int bid = 0; bid <= 13; bid++) BidMove(seat: state.turn, tricksBid: bid)],
    GamePhase.playing => [
        for (final card in state.hands[state.turn] ?? const []) PlayCardMove(seat: state.turn, card: card),
      ],
    GamePhase.roundEnd || GamePhase.matchOver => const [],
  };

  final List<Move> legal = candidates.where((m) => SpadesRulesEngine.isValidMove(state, m)).toList();
  assert(legal.isNotEmpty, 'No legal move found for ${state.turn} in phase ${state.phase} — engine bug');
  return legal[rng.nextInt(legal.length)];
}

/// Plays an entire match to completion using only random legal moves,
/// looping through rounds until `GamePhase.matchOver`. Used by the
/// engine's own test suite to stress-test thousands of realistic
/// games rather than hand-written scenarios alone; also useful as a
/// quick manual sanity check (`dart run` a small script that calls
/// this and prints `state.teamScores`).
///
/// Returns the final `GameState`; throws if the match does not
/// terminate within `maxRounds`, which would indicate a scoring or
/// win-condition bug rather than a slow-but-valid game (a real match
/// realistically ends well under 50 rounds).
GameState simulateFullGame({int? seed, int maxRounds = 200}) {
  final Random rng = seed == null ? Random() : Random(seed);
  GameState state = SpadesRulesEngine.newMatch(seed: seed);

  int guard = 0;
  while (state.phase != GamePhase.matchOver) {
    if (state.phase == GamePhase.roundEnd) {
      state = SpadesRulesEngine.startNextRound(state, seed: seed == null ? null : seed + state.roundNumber);
    } else {
      final Move move = chooseRandomLegalMove(state, rng);
      state = SpadesRulesEngine.applyMove(state, move);
    }
    guard++;
    if (guard > maxRounds * 60) {
      throw StateError('simulateFullGame did not terminate within $maxRounds rounds — likely an engine bug');
    }
  }
  return state;
}
