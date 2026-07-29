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

    // Shortcuts link to the business modules only - Accueil and Profil
    // are already reachable from the nav shell itself. This screen is
    // only ever reached by the passenger role in practice (drivers
    // land on /hub/driver/trips instead), but resolves the role-
    // appropriate list rather than assuming it, same as HubScaffold.
    final role = authState.value?.role;
    final moduleDestinations = hubDestinationsForRole(role).where(
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

/// One representative photo per module (Unsplash License - free for
/// commercial use, no attribution required - see assets/images/
/// modules/) so each shortcut is recognizable at a glance instead of
/// relying on a generic Material icon. Accueil/Profil never reach this
/// widget (filtered out in HomeHubScreen.build), so every real
/// destination.path here has an entry.
const _moduleImages = {
  '/hub/transport': 'assets/images/modules/transport.jpg',
  '/hub/hotels': 'assets/images/modules/hotels.jpg',
  '/hub/events': 'assets/images/modules/events.jpg',
  '/hub/commerce': 'assets/images/modules/commerce.jpg',
  '/hub/education': 'assets/images/modules/education.jpg',
};

class _ModuleShortcut extends StatelessWidget {
  const _ModuleShortcut({required this.destination});

  final HubDestination destination;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageAsset = _moduleImages[destination.path];

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.go(destination.path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageAsset != null)
              Image.asset(imageAsset, fit: BoxFit.cover)
            else
              Container(
                color: AppColors.primaryLight,
                child: Icon(destination.selectedIcon, color: AppColors.primary, size: 32),
              ),
            // Bottom-anchored scrim so the label stays legible over any
            // photo, without darkening the whole card.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
              child: Text(
                destination.label,
                style: textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
