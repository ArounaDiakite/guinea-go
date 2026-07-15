import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/hub/presentation/home_hub_screen.dart';
import 'features/hub/presentation/hub_scaffold.dart';
import 'features/hub/presentation/module_placeholder_screen.dart';
import 'features/hub/presentation/profile_screen.dart';
import 'features/identity/presentation/login_screen.dart';
import 'features/identity/presentation/register_screen.dart';
import 'features/splash/splash_screen.dart';

// Branch order here MUST match hubDestinations in
// features/hub/hub_destinations.dart - the shell picks its selected
// tab by branch index.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => HubScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/hub/home', builder: (context, state) => const HomeHubScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/transport',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Transport',
                icon: Icons.directions_bus_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/hotels',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Hôtels',
                icon: Icons.hotel_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/events',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Événements',
                icon: Icons.confirmation_number_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/commerce',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Commerce',
                icon: Icons.storefront_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hub/education',
              builder: (context, state) => const ModulePlaceholderScreen(
                title: 'Éducation',
                icon: Icons.school_rounded,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/hub/profile', builder: (context, state) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ],
);

class GuineaGoApp extends StatelessWidget {
  const GuineaGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Guinea Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
