import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:equatable/equatable.dart';

import 'game_state.dart';

/// Everything needed to put a suspended match back on the table exactly
/// as it was: the engine's [GameState] plus the few presentation-level
/// numbers the table screen needs that the engine deliberately doesn't
/// carry (round-start scores for the summary delta, the human's Nil tally
/// for achievements).
///
/// Bot strategies are stateless (they derive everything from the
/// `GameState`, including card tracking from `completedTricks`), so
/// nothing about the AIs needs saving.
class SavedMatch extends Equatable {
  const SavedMatch({
    required this.game,
    required this.difficulty,
    required this.roundStartScores,
    required this.roundStartBags,
    required this.savedAt,
    this.nilsMade = 0,
  });

  final GameState game;
  final AiDifficulty difficulty;

  /// Team scores/bags when the current round began.
  final Map<int, int> roundStartScores;
  final Map<int, int> roundStartBags;

  /// Nil bids the human has made good on so far this match.
  final int nilsMade;

  final DateTime savedAt;

  @override
  List<Object?> get props => [game, difficulty, roundStartScores, roundStartBags, nilsMade, savedAt];
}
