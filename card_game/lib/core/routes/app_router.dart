import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/ui_kit_showcase_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';

/// Route names as constants so screens navigate by name, never by
/// hand-typed path string (typo-proof, refactor-safe).
abstract class AppRoute {
  static const String splash = 'splash';
  static const String home = 'home';
  static const String settings = 'settings';
  static const String uiKit = 'ui-kit';

  // Added in later phases:
  // static const String table = 'table';        // Phase 05
  // static const String matchResult = 'result';  // Phase 05
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
      ],
    );
  }
}
