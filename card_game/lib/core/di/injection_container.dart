import 'package:card_game/core/storage/hive_local_store.dart';
import 'package:card_game/core/storage/local_store.dart';
import 'package:card_game/features/Profile/domain/profile_repository.dart';
import 'package:card_game/features/Settings/bloc/settings_cubit.dart';
import 'package:card_game/features/game/data/saved_match_repository_impl.dart';
import 'package:card_game/features/game/domain/repositories/saved_match_repository.dart';
import 'package:card_game/features/home/bloc/resume_match_cubit.dart';
import 'package:card_game/features/profile/data/profile_repository_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';   // capital
import '../audio/audio_service.dart';
import '../services/haptics_service.dart';
import '../theme/theme_cubit.dart';

/// Global service locator. Kept as plain `get_it` (no code generation)
/// so the project builds immediately without a `build_runner` step.
/// If the registration list grows large in later phases, this is the
/// place to introduce `injectable` — nothing above this layer needs to
/// change when that happens.
final GetIt sl = GetIt.instance;

/// Call once, before `runApp`. Order matters: singletons that other
/// singletons depend on must be registered first.
Future<void> initDependencies() async {
  // --- External / third-party ---------------------------------------
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  // --- Core services ---------------------------------------------------
  sl.registerLazySingleton<AudioService>(AudioService.new);
  sl.registerLazySingleton<HapticsService>(HapticsService.new);

  // --- App-wide cubits (registered as factories that return the same
  // instance for the app's lifetime would be a singleton; these are
  // singletons because exactly one ThemeCubit/SettingsCubit should
  // exist for the whole app, same as your old app's AuthCubit). -------
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(prefs: sl()));
  sl.registerLazySingleton<SettingsCubit>(() => SettingsCubit(prefs: sl()));

  // --- Persistence (Phase 09) ----------------------------------------
  // Settings + theme stay on SharedPreferences (simple flags). Structured
  // data — profile, stats, history, achievements and the in-progress
  // match — lives in Hive behind the LocalStore interface, so repositories
  // are tested against InMemoryLocalStore and never import Hive directly.
  final HiveLocalStore store = await HiveLocalStore.open();
  sl.registerSingleton<LocalStore>(store);
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(store: sl()));
  sl.registerLazySingleton<SavedMatchRepository>(() => SavedMatchRepositoryImpl(store: sl()));
  sl.registerLazySingleton<ProfileCubit>(() => ProfileCubit(repository: sl()));
  sl.registerLazySingleton<ResumeMatchCubit>(() => ResumeMatchCubit(repository: sl()));

  // Phase 10 will add: registerLazySingleton<AuthCubit>(...), matchmaking client
}
