import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/admin_shell.dart';
import 'features/dashboard/presentation/dashboard_home_screen.dart';
import 'features/identity/application/auth_controller.dart';
import 'features/identity/presentation/login_screen.dart';

/// Overridable in tests, same purpose as mobile/'s initialLocationProvider.
final initialLocationProvider = Provider<String>((ref) => '/');

/// Route guard for the whole app: '/login' is reachable without a
/// session; everything else requires one, and a session that somehow
/// exists but isn't a system_administrator (shouldn't happen -
/// AuthController.build() already clears those) is treated the same as
/// no session. An already-authenticated visit to '/login' bounces
/// straight to the dashboard instead of showing the form again.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    redirect: (context, state) async {
      final user = await ref.read(authControllerProvider.future);
      final loggingIn = state.matchedLocation == '/login';

      if (user == null) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: _routes,
  );
});

final List<RouteBase> _routes = [
  GoRoute(
    path: '/login',
    builder: (context, state) => const LoginScreen(),
  ),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => AdminShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardHomeScreen()),
        ],
      ),
    ],
  ),
];

class AdminDashboardApp extends ConsumerWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Guinea Go Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
