import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:equatable/equatable.dart';

/// One finished match, as shown in the profile's history list and folded
/// into [PlayerStats]. Matches the human abandons are *not* recorded —
/// quitting never counts as a loss.
class MatchRecord extends Equatable {
  const MatchRecord({
    required this.playedAt,
    required this.difficulty,
    required this.won,
    required this.ourScore,
    required this.theirScore,
    required this.rounds,
    this.nilsMade = 0,
  });

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      playedAt: DateTime.parse(json['playedAt'] as String),
      difficulty: AiDifficulty.values.asNameMap()[json['difficulty']] ?? AiDifficulty.medium,
      won: json['won'] as bool,
      ourScore: (json['ourScore'] as num).toInt(),
      theirScore: (json['theirScore'] as num).toInt(),
      rounds: (json['rounds'] as num).toInt(),
      nilsMade: (json['nilsMade'] as num?)?.toInt() ?? 0,
    );
  }

  final DateTime playedAt;
  final AiDifficulty difficulty;
  final bool won;
  final int ourScore;
  final int theirScore;
  final int rounds;

  /// Nil bids the human made good on during this match.
  final int nilsMade;

  /// Positive when we finished ahead.
  int get margin => ourScore - theirScore;

  Map<String, Object?> toJson() => {
        'playedAt': playedAt.toIso8601String(),
        'difficulty': difficulty.name,
        'won': won,
        'ourScore': ourScore,
        'theirScore': theirScore,
        'rounds': rounds,
        'nilsMade': nilsMade,
      };

  @override
  List<Object?> get props => [playedAt, difficulty, won, ourScore, theirScore, rounds, nilsMade];
}
