import 'package:card_game/features/Settings/presentation/pages/settings_page.dart';
import 'package:card_game/features/Splash/presentation/pages/splash_page.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/game/Presentation/pages/game_table_page.dart';
import 'package:card_game/features/Profile/presentation/pages/profile_page.dart';
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
  static const String profile = 'profile'; // Phase 09

  // Added in later phases:
  // static const String matchResult = 'result';  // folded into the
  //   table route itself (see GameTablePage's MatchResultSheet) rather
  //   than a separate route — there's nothing to deep-link to.
}

/// `extra` for the table route. Start a fresh match with just a
/// [difficulty], or put a suspended match back on the table with
/// [resume] (its own difficulty wins over [difficulty]).
///
/// The route also still accepts a bare `AiDifficulty` as `extra`, so
/// any caller written before Phase 09 keeps working.
class TableRouteArgs {
  const TableRouteArgs({this.difficulty = AiDifficulty.medium, this.resume});

  final AiDifficulty difficulty;
  final SavedMatch? resume;
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
          // `extra` is a TableRouteArgs (new match or resume), or a bare
          // AiDifficulty from the Phase 05 call site; default to Medium
          // if the route is ever reached without it (e.g. a deep link).
          builder: (context, state) {
            final Object? extra = state.extra;
            final TableRouteArgs args = switch (extra) {
              final TableRouteArgs a => a,
              final AiDifficulty d => TableRouteArgs(difficulty: d),
              _ => const TableRouteArgs(),
            };
            return GameTablePage(
              difficulty: args.resume?.difficulty ?? args.difficulty,
              resume: args.resume,
            );
          },
        ),
        GoRoute(
          path: '/profile',
          name: AppRoute.profile,
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    );
  }
}
