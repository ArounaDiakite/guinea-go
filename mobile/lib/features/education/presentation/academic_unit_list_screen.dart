import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../models/academic_unit.dart';

class AcademicUnitListScreen extends ConsumerWidget {
  const AcademicUnitListScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(academicUnitsProvider(institutionId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Classes / départements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/school/academic-units/new', extra: institutionId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: unitsAsync.when(
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
                    onPressed: () => ref.invalidate(academicUnitsProvider(institutionId)),
                  ),
                ],
              ),
            ),
          ),
          data: (units) {
            if (units.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.class_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune classe enregistrée pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: units.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _AcademicUnitCard(institutionId: institutionId, unit: units[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AcademicUnitCard extends StatelessWidget {
  const _AcademicUnitCard({required this.institutionId, required this.unit});

  final String institutionId;
  final AcademicUnit unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push(
        '/hub/school/academic-units/${unit.id}/edit',
        extra: institutionId,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.class_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  unit.level,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
