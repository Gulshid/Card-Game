import '../engine/spades_rules_engine.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/seat.dart';
import 'ai_strategy.dart';

/// Plays a whole match to completion with one [AiStrategy] per seat.
///
/// Every chosen move goes through `SpadesRulesEngine.applyMove`, which
/// throws a [StateError] on an illegal move — so a clean return is
/// proof that no bot ever cheated. Used by the tests, and handy for
/// tuning bots offline.
GameState playMatchWithStrategies(
  Map<Seat, AiStrategy> strategies, {
  int? seed,
  int maxRounds = 300,
  Seat dealer = Seat.north,
}) {
  GameState state = SpadesRulesEngine.newMatch(dealer: dealer, seed: seed);

  int guard = 0;
  while (state.phase != GamePhase.matchOver) {
    if (state.phase == GamePhase.roundEnd) {
      state = SpadesRulesEngine.startNextRound(state, seed: seed == null ? null : seed + state.roundNumber);
    } else {
      final AiStrategy? strategy = strategies[state.turn];
      if (strategy == null) {
        throw StateError('No strategy supplied for ${state.turn}');
      }
      final Move move = strategy.chooseMove(state);
      state = SpadesRulesEngine.applyMove(state, move);
    }
    guard++;
    if (guard > maxRounds * 60) {
      throw StateError('Match did not finish within $maxRounds rounds');
    }
  }
  return state;
}
