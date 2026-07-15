import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/company_controller.dart';
import '../models/managed_driver.dart';

class CompanyDriversScreen extends ConsumerWidget {
  const CompanyDriversScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(companyDriversProvider(companyId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chauffeurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/company/drivers/new', extra: companyId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: driversAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppErrorBanner(message: extractApiErrorMessage(error)),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Réessayer',
                    variant: AppButtonVariant.secondary,
                    expand: false,
                    onPressed: () => ref.invalidate(companyDriversProvider(companyId)),
                  ),
                ],
              ),
            ),
          ),
          data: (drivers) {
            if (drivers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun chauffeur enregistré pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: drivers.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _DriverCard(driver: drivers[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

const _statusStyles = {
  DriverStatus.available: _StatusStyle('Disponible', AppColors.secondaryDark, AppColors.secondaryLight),
  DriverStatus.onTrip: _StatusStyle('En trajet', AppColors.info, AppColors.infoLight),
  DriverStatus.onLeave: _StatusStyle('En congé', AppColors.accentDark, AppColors.accentLight),
  DriverStatus.suspended: _StatusStyle('Suspendu', AppColors.error, AppColors.errorLight),
  DriverStatus.inactive: _StatusStyle('Inactif', AppColors.textSecondary, AppColors.surfaceVariant),
  DriverStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final ManagedDriver driver;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyles[driver.status]!;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              driver.firstName.isNotEmpty ? driver.firstName[0].toUpperCase() : '?',
              style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.fullName, style: textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Matricule ${driver.employeeNumber} · ${driver.phone}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                if (driver.userId == null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Aucun compte de connexion lié',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(style.label, style: textTheme.labelSmall?.copyWith(color: style.foreground)),
          ),
        ],
      ),
    );
  }
}
