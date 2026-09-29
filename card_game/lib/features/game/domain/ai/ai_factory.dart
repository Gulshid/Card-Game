import 'dart:math' as math;

import 'ai_difficulty.dart';
import 'ai_strategy.dart';
import 'easy_ai.dart';
import 'hard_ai.dart';
import 'medium_ai.dart';

/// Builds the strategy for a difficulty. [random] only affects Easy (the
/// only non-deterministic tier); pass a seeded one for reproducible games.
AiStrategy createAiStrategy(AiDifficulty difficulty, {math.Random? random}) {
  switch (difficulty) {
    case AiDifficulty.easy:
      return EasyAi(random: random);
    case AiDifficulty.medium:
      return const MediumAi();
    case AiDifficulty.hard:
      return const HardAi();
  }
}
