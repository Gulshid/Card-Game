import 'package:card_game/features/profile/domain/models/achievements.dart';
import 'package:card_game/features/profile/domain/models/match_record.dart';
import 'package:card_game/features/profile/domain/models/player_profile.dart';
import 'package:card_game/features/profile/domain/models/player_stats.dart';
import 'package:equatable/equatable.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.isLoaded = false,
    this.profile = const PlayerProfile(),
    this.stats = const PlayerStats(),
    this.history = const [],
    this.unlocked = const <Achievement>{},
  });

  /// False only until the first read from disk completes (the splash
  /// screen waits for it, so UI normally never sees `false`).
  final bool isLoaded;
  final PlayerProfile profile;
  final PlayerStats stats;
  final List<MatchRecord> history;
  final Set<Achievement> unlocked;

  bool isCardBackUnlocked(CardBackStyle style) => style.isUnlockedWith(unlocked);

  ProfileState copyWith({
    bool? isLoaded,
    PlayerProfile? profile,
    PlayerStats? stats,
    List<MatchRecord>? history,
    Set<Achievement>? unlocked,
  }) {
    return ProfileState(
      isLoaded: isLoaded ?? this.isLoaded,
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      history: history ?? this.history,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  @override
  List<Object?> get props => [isLoaded, profile, stats, history, unlocked];
}
