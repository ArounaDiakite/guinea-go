import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_button.dart';
import '../identity/application/auth_controller.dart';

/// Temporary landing spot after login/register - just confirms the
/// session actually holds a user, nothing more. Replaced by the real
/// home screen in a later task.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: authState.when(
              data: (user) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration_rounded, color: AppColors.primary, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user != null ? 'Connecté en tant que ${user.firstName}' : 'Non connecté',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Le véritable écran d'accueil arrive dans une prochaine étape.",
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Se déconnecter',
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => Text('Erreur : $error'),
            ),
          ),
        ),
      ),
    );
  }
}
