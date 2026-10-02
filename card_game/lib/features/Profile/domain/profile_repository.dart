import 'package:equatable/equatable.dart';

import 'models/achievements.dart';
import 'models/match_record.dart';
import 'models/player_profile.dart';
import 'models/player_stats.dart';

/// What changed when a finished match was recorded.
class MatchRecordOutcome extends Equatable {
  const MatchRecordOutcome({
    required this.stats,
    required this.history,
    required this.unlocked,
    required this.newlyUnlocked,
  });

  final PlayerStats stats;
  final List<MatchRecord> history;

  /// Every achievement the player now owns.
  final Set<Achievement> unlocked;

  /// Only the ones earned by *this* match (empty most of the time).
  final List<Achievement> newlyUnlocked;

  @override
  List<Object?> get props => [stats, history, unlocked, newlyUnlocked];
}

/// Everything persistent about the player except the in-progress match
/// (see `SavedMatchRepository`). Reads never throw: unreadable data falls
/// back to defaults.
abstract interface class ProfileRepository {
  Future<PlayerProfile> loadProfile();

  Future<void> saveProfile(PlayerProfile profile);

  Future<PlayerStats> loadStats();

  /// Newest first, capped at [kMaxHistory].
  Future<List<MatchRecord>> loadHistory();

  Future<Set<Achievement>> loadUnlocked();

  /// Folds [record] into stats and history, evaluates achievements and
  /// persists all of it.
  Future<MatchRecordOutcome> recordMatch(MatchRecord record);

  /// Wipes stats, history and achievements. Keeps the player's name and
  /// avatar, but resets the card back to classic (the chosen one may no
  /// longer be unlocked).
  Future<void> resetProgress();
}

/// How many finished matches the history list keeps.
const int kMaxHistory = 20;
