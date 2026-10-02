import 'dart:convert';

import 'package:card_game/core/storage/local_store.dart';
import 'package:card_game/features/profile/domain/achievement_rules.dart';
import 'package:card_game/features/profile/domain/models/achievements.dart';
import 'package:card_game/features/profile/domain/models/match_record.dart';
import 'package:card_game/features/profile/domain/models/player_profile.dart';
import 'package:card_game/features/profile/domain/models/player_stats.dart';
import 'package:card_game/features/profile/domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required LocalStore store}) : _store = store;

  final LocalStore _store;

  static const String _kProfile = 'profile.data';
  static const String _kStats = 'profile.stats';
  static const String _kHistory = 'profile.history';
  static const String _kUnlocked = 'profile.unlocked';

  /// Reads and parses [key]; any missing/corrupt value yields [fallback].
  Future<T> _read<T>(String key, T Function(Object? decoded) parse, T fallback) async {
    final String? raw = await _store.read(key);
    if (raw == null) return fallback;
    try {
      return parse(jsonDecode(raw));
    } on Object {
      return fallback;
    }
  }

  @override
  Future<PlayerProfile> loadProfile() {
    return _read(_kProfile, (d) => PlayerProfile.fromJson((d! as Map).cast<String, dynamic>()), const PlayerProfile());
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) => _store.write(_kProfile, jsonEncode(profile.toJson()));

  @override
  Future<PlayerStats> loadStats() {
    return _read(_kStats, (d) => PlayerStats.fromJson((d! as Map).cast<String, dynamic>()), const PlayerStats());
  }

  @override
  Future<List<MatchRecord>> loadHistory() {
    return _read(
      _kHistory,
      (d) => [for (final Object? e in d! as List) MatchRecord.fromJson((e! as Map).cast<String, dynamic>())],
      const <MatchRecord>[],
    );
  }

  @override
  Future<Set<Achievement>> loadUnlocked() {
    return _read(
      _kUnlocked,
      (d) {
        final Map<String, Achievement> byName = Achievement.values.asNameMap();
        return {
          for (final Object? n in d! as List)
            if (byName[n] != null) byName[n]!,
        };
      },
      const <Achievement>{},
    );
  }

  @override
  Future<MatchRecordOutcome> recordMatch(MatchRecord record) async {
    final PlayerStats stats = (await loadStats()).applyMatch(record);
    final List<MatchRecord> history = [record, ...await loadHistory()].take(kMaxHistory).toList();

    final Set<Achievement> alreadyUnlocked = await loadUnlocked();
    final Set<Achievement> earnedNow = AchievementRules.evaluate(stats);
    final List<Achievement> newlyUnlocked = [
      for (final Achievement a in Achievement.values)
        if (earnedNow.contains(a) && !alreadyUnlocked.contains(a)) a,
    ];
    final Set<Achievement> unlocked = {...alreadyUnlocked, ...newlyUnlocked};

    await _store.write(_kStats, jsonEncode(stats.toJson()));
    await _store.write(_kHistory, jsonEncode([for (final MatchRecord r in history) r.toJson()]));
    await _store.write(_kUnlocked, jsonEncode([for (final Achievement a in unlocked) a.name]));

    return MatchRecordOutcome(stats: stats, history: history, unlocked: unlocked, newlyUnlocked: newlyUnlocked);
  }

  @override
  Future<void> resetProgress() async {
    await _store.delete(_kStats);
    await _store.delete(_kHistory);
    await _store.delete(_kUnlocked);
    final PlayerProfile profile = await loadProfile();
    await saveProfile(profile.copyWith(cardBack: CardBackStyle.classic));
  }
}
