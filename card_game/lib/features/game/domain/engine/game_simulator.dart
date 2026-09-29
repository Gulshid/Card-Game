import 'dart:math';

import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import 'spades_rules_engine.dart';

/// Picks a uniformly random *legal* move for whoever's turn it is.
///
/// Bids are drawn from [minBid]..[maxBid] (default 2..3), **not** the full
/// 0..13 the engine would accept. This is deliberate: a random bot bidding
/// uniformly over 0..13 averages a ~13-trick team target while winning
/// ~6.5 tricks, so every round is a large failed-bid penalty and neither
/// team ever climbs to 500 — the match simply never ends. (Measured: 0 of
/// 50 such games finished.) Bids of 2..3 are made most rounds, so scores
/// drift upward and matches finish in ~27 rounds on average.
///
/// The engine still accepts any 0..13 bid — that's covered by the
/// `bidding` tests in spades_rules_engine_test.dart — this range only
/// shapes what the *simulator* chooses.
Move chooseRandomLegalMove(
  GameState state,
  Random rng, {
  int minBid = 2,
  int maxBid = 3,
}) {
  final List<Move> candidates = switch (state.phase) {
    GamePhase.bidding => [
        for (int bid = minBid; bid <= maxBid; bid++) BidMove(seat: state.turn, tricksBid: bid),
      ],
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
/// engine's own test suite to stress-test many realistic games rather
/// than hand-written scenarios alone.
///
/// Returns the final `GameState`; throws if the match does not
/// terminate within `maxRounds` (200 is ~3x the longest game seen in
/// 200 simulated seeds).
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
