import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/routes/app_router.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/core/theme/app_theme.dart';
import 'package:card_game/core/theme/theme_cubit.dart';
import 'package:card_game/features/Settings/bloc/settings_cubit.dart';
import 'package:card_game/features/Settings/bloc/settings_state.dart';
import 'package:card_game/features/home/bloc/resume_match_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const SpadesRoyaleApp());
}
// 1. terminal 1 :dart run server/spades_server.dart

// 2. terminal 2 : flutter run --dart-define=SPADES_SERVER_URL=ws://localhost:8080/ws

class SpadesRoyaleApp extends StatefulWidget {
  const SpadesRoyaleApp({super.key});

  @override
  State<SpadesRoyaleApp> createState() => _SpadesRoyaleAppState();
}

class _SpadesRoyaleAppState extends State<SpadesRoyaleApp> {
  late final RouterConfig<Object> _router = AppRouter.create();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ThemeCubit>()),
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<ProfileCubit>()),
        BlocProvider(create: (_) => sl<ResumeMatchCubit>()),
      ],
      child: BlocListener<SettingsCubit, SettingsState>(
        // Any mute/volume change from the Settings screen is forwarded
        // live to the shared AudioService, so a slider drag is audible
        // immediately even mid-game. Real SFX/music assets arrive in
        // Phase 08; the plumbing is correct starting now.
        listener: (context, state) {
          sl<AudioService>().applySettings(
            musicOn: state.musicOn,
            sfxOn: state.sfxOn,
            musicVolume: state.musicVolume,
            sfxVolume: state.sfxVolume,
          );
          sl<HapticsService>().enabled = state.hapticsOn;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScreenUtilInit(
              designSize: _designSize(constraints.maxWidth),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (_, __) => _AppEntry(router: _router),
            );
          },
        ),
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry({required this.router});

  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.watch<ThemeCubit>().state;

    return MaterialApp.router(
      title: 'Spades Royale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (ctx, child) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );
        return child!;
      },
    );
  }
}


Size _designSize(double width) {
  if (width < 600) return const Size(360, 800); // phone
  if (width < 1200) return const Size(834, 1194); // tablet
  return const Size(1440, 1024); // desktop
}
