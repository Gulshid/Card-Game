import 'dart:math' as math;

import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:equatable/equatable.dart';

import 'match_record.dart';

/// Lifetime totals. Immutable; [applyMatch] returns the updated copy, so
/// the rule for "what does one finished match change?" lives in exactly
/// one pure, unit-tested place.
class PlayerStats extends Equatable {
  const PlayerStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.nilsMade = 0,
    this.biggestWinMargin = 0,
    this.winsByDifficulty = const {},
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    int readInt(String key) {
      final Object? v = json[key];
      return v is num ? v.toInt() : 0;
    }

    final Object? rawByDifficulty = json['winsByDifficulty'];
    final Map<AiDifficulty, int> byDifficulty = {};
    if (rawByDifficulty is Map) {
      for (final MapEntry<Object?, Object?> e in rawByDifficulty.entries) {
        final AiDifficulty? d = AiDifficulty.values.asNameMap()[e.key];
        if (d != null && e.value is num) byDifficulty[d] = (e.value! as num).toInt();
      }
    }

    return PlayerStats(
      gamesPlayed: readInt('gamesPlayed'),
      wins: readInt('wins'),
      currentStreak: readInt('currentStreak'),
      bestStreak: readInt('bestStreak'),
      nilsMade: readInt('nilsMade'),
      biggestWinMargin: readInt('biggestWinMargin'),
      winsByDifficulty: byDifficulty,
    );
  }

  final int gamesPlayed;
  final int wins;

  /// Consecutive wins right now; any loss resets it to 0.
  final int currentStreak;
  final int bestStreak;
  final int nilsMade;
  final int biggestWinMargin;
  final Map<AiDifficulty, int> winsByDifficulty;

  int get losses => gamesPlayed - wins;

  /// 0.0 – 1.0; 0 when no games have been played (never NaN).
  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  int winsOn(AiDifficulty difficulty) => winsByDifficulty[difficulty] ?? 0;

  PlayerStats applyMatch(MatchRecord record) {
    final int streak = record.won ? currentStreak + 1 : 0;
    final Map<AiDifficulty, int> byDifficulty = {...winsByDifficulty};
    if (record.won) byDifficulty[record.difficulty] = winsOn(record.difficulty) + 1;

    return PlayerStats(
      gamesPlayed: gamesPlayed + 1,
      wins: wins + (record.won ? 1 : 0),
      currentStreak: streak,
      bestStreak: math.max(bestStreak, streak),
      nilsMade: nilsMade + record.nilsMade,
      biggestWinMargin: record.won ? math.max(biggestWinMargin, record.margin) : biggestWinMargin,
      winsByDifficulty: byDifficulty,
    );
  }

  Map<String, Object?> toJson() => {
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'nilsMade': nilsMade,
        'biggestWinMargin': biggestWinMargin,
        'winsByDifficulty': {
          for (final MapEntry<AiDifficulty, int> e in winsByDifficulty.entries) e.key.name: e.value,
        },
      };

  @override
  List<Object?> get props =>
      [gamesPlayed, wins, currentStreak, bestStreak, nilsMade, biggestWinMargin, winsByDifficulty];
}
