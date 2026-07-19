import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../hub/hub_destinations.dart';
import '../identity/application/auth_controller.dart';
import 'splash_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(backendConnectivityProvider);
    final textTheme = Theme.of(context).textTheme;

    // Side effect, not a rebuild-driven value - once the connectivity
    // check succeeds, decide where to land: straight on the hub if a
    // still-valid session is sitting in storage, otherwise login.
    ref.listen(backendConnectivityProvider, (previous, next) {
      if (next.hasValue) {
        _proceedPastSplash(context, ref);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _BrandMark(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Guinea Go',
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Transport, hôtels, événements, commerce\net éducation - tout en un seul endroit.',
                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              _ConnectivityStatus(connectivity: connectivity),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// A brief pause so the checkmark actually registers with the user,
/// then reads the session-restore result (authControllerProvider's
/// build() already checked storage for a token and, if present,
/// validated it against GET /users/me) to decide the landing screen.
Future<void> _proceedPastSplash(BuildContext context, WidgetRef ref) async {
  await Future.delayed(const Duration(milliseconds: 500));

  final user = await ref.read(authControllerProvider.future).catchError((_) => null);

  if (!context.mounted) return;

  if (user == null) {
    context.go('/login');
    return;
  }

  context.go(landingRouteForRole(user.role));
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.explore_outlined,
        color: AppColors.textOnPrimary,
        size: 44,
      ),
    );
  }
}

class _ConnectivityStatus extends StatelessWidget {
  const _ConnectivityStatus({required this.connectivity});

  final AsyncValue<String> connectivity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return connectivity.when(
      loading: () => Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Connexion au serveur...',
            style: textTheme.bodySmall,
          ),
        ],
      ),
      error: (error, stackTrace) => Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Impossible de joindre le serveur.\nVérifiez votre connexion et réessayez.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réessayer',
            variant: AppButtonVariant.secondary,
            expand: false,
            onPressed: () {
              // ignore: unused_result
              ProviderScope.containerOf(context).refresh(backendConnectivityProvider);
            },
          ),
        ],
      ),
      data: (message) => Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: textTheme.bodySmall?.copyWith(color: AppColors.success),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
