import 'package:card_game/features/Settings/presentation/pages/settings_page.dart';
import 'package:card_game/features/Splash/presentation/pages/splash_page.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/presentation/pages/game_table_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/ui_kit_showcase_page.dart';

/// Route names as constants so screens navigate by name, never by
/// hand-typed path string (typo-proof, refactor-safe).
abstract class AppRoute {
  static const String splash = 'splash';
  static const String home = 'home';
  static const String settings = 'settings';
  static const String uiKit = 'ui-kit';
  static const String table = 'table'; // Phase 05

  // Added in later phases:
  // static const String matchResult = 'result';  // folded into the
  //   table route itself (see GameTablePage's MatchResultSheet) rather
  //   than a separate route — there's nothing to deep-link to.
  // static const String profile = 'profile';     // Phase 09
}

abstract class AppRouter {
  static RouterConfig<Object> create() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: AppRoute.splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/home',
          name: AppRoute.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/settings',
          name: AppRoute.settings,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/ui-kit',
          name: AppRoute.uiKit,
          builder: (context, state) => const UiKitShowcasePage(),
        ),
        GoRoute(
          path: '/table',
          name: AppRoute.table,
          // `extra` carries the AiDifficulty chosen on Home's
          // DifficultySelectSheet; default to Medium if the route is
          // ever reached without it (e.g. a future deep link).
          builder: (context, state) => GameTablePage(difficulty: (state.extra as AiDifficulty?) ?? AiDifficulty.medium),
        ),
      ],
    );
  }
}
