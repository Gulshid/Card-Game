import 'package:card_game/features/Settings/bloc/settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Phase 09 will add: registerLazySingleton<StatsRepository>(...)
  // Phase 10 will add: registerLazySingleton<AuthCubit>(...), matchmaking client
}
