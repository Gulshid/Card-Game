import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/Profile/domain/models/match_record.dart';
import 'package:card_game/features/Profile/domain/models/player_profile.dart';
import 'package:card_game/features/Profile/domain/models/player_stats.dart';
import 'package:card_game/features/Profile/domain/profile_repository.dart';
import 'package:card_game/features/Profile/bloc/profile_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide owner of the player's profile, stats and unlocks. A singleton
/// (like `SettingsCubit`) so the table, home and profile screens all see
/// one consistent, live copy.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const ProfileState());

  final ProfileRepository _repository;
  Future<void>? _loading;

  /// Loads from disk once; later calls return the same future. The splash
  /// screen awaits this so Home never flashes empty data.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final PlayerProfile profile = await _repository.loadProfile();
    final PlayerStats stats = await _repository.loadStats();
    final List<MatchRecord> history = await _repository.loadHistory();
    final Set<Achievement> unlocked = await _repository.loadUnlocked();
    if (isClosed) return;
    emit(ProfileState(isLoaded: true, profile: profile, stats: stats, history: history, unlocked: unlocked));
  }

  Future<void> updateName(String raw) async {
    final String? name = PlayerProfile.sanitizeName(raw);
    if (name == null || name == state.profile.name) return;
    await _saveProfile(state.profile.copyWith(name: name));
  }

  Future<void> updateAvatar(int avatarId) async {
    final int clamped = avatarId.clamp(0, PlayerProfile.avatarCount - 1);
    if (clamped == state.profile.avatarId) return;
    await _saveProfile(state.profile.copyWith(avatarId: clamped));
  }

  /// Ignored if [style] hasn't been unlocked yet.
  Future<void> selectCardBack(CardBackStyle style) async {
    if (!state.isCardBackUnlocked(style) || style == state.profile.cardBack) return;
    await _saveProfile(state.profile.copyWith(cardBack: style));
  }

  Future<void> _saveProfile(PlayerProfile profile) async {
    emit(state.copyWith(profile: profile));
    await _repository.saveProfile(profile);
  }

  /// Passed to `GameCubit` as its `onMatchFinished` callback. Returns the
  /// achievements this match unlocked so the result sheet can show them.
  Future<List<Achievement>> recordMatch(MatchRecord record) async {
    final MatchRecordOutcome outcome = await _repository.recordMatch(record);
    if (!isClosed) {
      emit(state.copyWith(stats: outcome.stats, history: outcome.history, unlocked: outcome.unlocked));
    }
    return outcome.newlyUnlocked;
  }

  Future<void> resetProgress() async {
    await _repository.resetProgress();
    if (isClosed) return;
    emit(
      state.copyWith(
        stats: const PlayerStats(),
        history: const [],
        unlocked: const <Achievement>{},
        profile: state.profile.copyWith(cardBack: CardBackStyle.classic),
      ),
    );
  }
}
