import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../identity/application/auth_controller.dart';
import '../hub_destinations.dart';

/// Below this width the hub uses a bottom nav bar (a one-handed phone
/// habit); at or above it, a side rail - a bottom bar stretched across
/// a tablet/web window stops being reachable by a thumb and starts
/// looking like a phone layout forced onto a bigger screen.
const _railBreakpoint = 720.0;
const _extendedRailBreakpoint = 1000.0;

/// Shell around every hub tab (StatefulShellRoute branch) - picks the
/// nav chrome by width and keeps each tab's own navigation stack alive
/// when switching away and back (that's what indexedStack buys us over
/// plain GoRoutes).
///
/// The branch list itself (app.dart's `_routes`) is fixed regardless
/// of role - only which of its branches are actually *offered* here is
/// role-dependent (hubDestinationsForRole). That keeps this widget from
/// ever needing to rebuild GoRouter itself: the nav bar/rail just shows
/// a filtered view of destinations and translates taps back to their
/// real branch index.
class HubScaffold extends ConsumerWidget {
  const HubScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).value?.role;
    final destinations = hubDestinationsForRole(role);
    final width = MediaQuery.sizeOf(context).width;

    final selectedPosition = destinations.indexWhere(
      (destination) => destination.branchIndex == navigationShell.currentIndex,
    );
    final effectiveSelected = selectedPosition == -1 ? 0 : selectedPosition;

    void onDestinationSelected(int position) {
      final branchIndex = destinations[position].branchIndex;
      navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell.currentIndex,
      );
    }

    if (width < _railBreakpoint) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: effectiveSelected,
          onDestinationSelected: onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon, color: AppColors.primary),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: effectiveSelected,
            onDestinationSelected: onDestinationSelected,
            extended: width >= _extendedRailBreakpoint,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primaryLight,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Icon(Icons.explore_rounded, color: AppColors.primary, size: 30),
            ),
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
