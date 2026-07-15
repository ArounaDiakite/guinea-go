import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../identity/application/auth_controller.dart';
import '../hub_destinations.dart';

class HomeHubScreen extends ConsumerWidget {
  const HomeHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    // Shortcuts link to the 5 business modules only - Accueil and
    // Profil are already reachable from the nav shell itself.
    final moduleDestinations = hubDestinations.where(
      (destination) => destination.path != '/hub/home' && destination.path != '/hub/profile',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Guinea Go')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _WelcomeCard(firstName: authState.asData?.value?.firstName),
            const SizedBox(height: AppSpacing.xl),
            Text('Explorer', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.35,
              children: [
                for (final destination in moduleDestinations) _ModuleShortcut(destination: destination),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName != null ? 'Bonjour, $firstName' : 'Bonjour',
            style: textTheme.headlineMedium?.copyWith(color: AppColors.textOnPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Où allez-vous aujourd\'hui ?',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleShortcut extends StatelessWidget {
  const _ModuleShortcut({required this.destination});

  final HubDestination destination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.go(destination.path),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(destination.selectedIcon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(destination.label, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}
