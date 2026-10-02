import 'models/achievements.dart';
import 'models/player_stats.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';

/// Pure "which achievements do these lifetime stats deserve?" function.
/// Re-evaluated after every match; the repository unions the result with
/// what was already unlocked, so achievements are never revoked.
abstract class AchievementRules {
  static const int streakTarget = 3;
  static const int veteranMatches = 10;
  static const int dominationMargin = 200;

  static Set<Achievement> evaluate(PlayerStats stats) {
    return {
      if (stats.wins >= 1) Achievement.firstWin,
      if (stats.bestStreak >= streakTarget) Achievement.hotStreak,
      if (stats.nilsMade >= 1) Achievement.nilMaster,
      if (stats.winsOn(AiDifficulty.hard) >= 1) Achievement.giantSlayer,
      if (stats.gamesPlayed >= veteranMatches) Achievement.veteran,
      if (stats.biggestWinMargin >= dominationMargin) Achievement.domination,
    };
  }
}
