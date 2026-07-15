import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../identity/application/auth_controller.dart';

// Source of truth for these codes: backend/app/core/constants.py::UserRole.
// Public registration only ever creates `passenger`, but /auth/login can
// return any role, so every one of them gets a French label here.
const _roleLabels = {
  'passenger': 'Passager',
  'company_owner': 'Propriétaire de compagnie',
  'driver': 'Chauffeur',
  'hotel_owner': 'Propriétaire d\'hôtel',
  'event_organizer': 'Organisateur d\'événements',
  'school_administrator': 'Administrateur scolaire',
  'store_manager': 'Gérant de magasin',
  'system_administrator': 'Administrateur système',
};

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: authState.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Non connecté'));
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                      style: textTheme.displayLarge?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text('${user.firstName} ${user.lastName}', style: textTheme.headlineMedium),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    _roleLabels[user.role] ?? user.role,
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
                      const Divider(height: AppSpacing.xl),
                      _ProfileRow(icon: Icons.phone_outlined, label: 'Téléphone', value: user.phone),
                      const Divider(height: AppSpacing.xl),
                      _ProfileRow(icon: Icons.location_city_outlined, label: 'Ville', value: user.city),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Se déconnecter',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(child: Text('Impossible de charger le profil.')),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.labelMedium),
              Text(value, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
