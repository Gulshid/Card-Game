import '../models/game_state.dart';
import '../models/move.dart';

/// Anything that can pick a move for whoever's turn it is in [state].
///
/// **Fairness contract:** an implementation may read only the acting
/// seat's own hand plus public information (bids, the current trick,
/// completed tricks, scores). It must never inspect another seat's
/// `state.hands` entry. `ai_strategies_test.dart` enforces this by
/// shuffling every other hand and checking the decision doesn't change.
///
/// Returned moves must already be legal — callers apply them with
/// `SpadesRulesEngine.applyMove`, which throws on an illegal move.
abstract interface class AiStrategy {
  Move chooseMove(GameState state);
}
