import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../identity/application/auth_controller.dart';
import '../dashboard_destinations.dart';

/// Persistent, always-expanded side rail - this app is desktop/large-
/// screen only (unlike mobile/'s HubScaffold, which adapts between a
/// bottom nav bar and a rail depending on width), so there's no
/// narrow-width branch to handle.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            backgroundColor: AppColors.surface,
            selectedIndex: adminDestinations.indexWhere(
              (destination) => destination.branchIndex == navigationShell.currentIndex,
            ),
            onDestinationSelected: (index) =>
                navigationShell.goBranch(adminDestinations[index].branchIndex),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.textOnPrimary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Guinea Go Admin', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user.firstName} ${user.lastName}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final destination in adminDestinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
