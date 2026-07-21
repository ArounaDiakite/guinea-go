import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../models/academic_unit.dart';
import '../models/fee_schedule.dart';

class FeeScheduleListScreen extends ConsumerWidget {
  const FeeScheduleListScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeSchedulesAsync = ref.watch(feeSchedulesProvider(institutionId));
    final unitsAsync = ref.watch(academicUnitsProvider(institutionId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Frais de scolarité')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/school/fee-schedules/new', extra: institutionId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: feeSchedulesAsync.when(
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
                    onPressed: () => ref.invalidate(feeSchedulesProvider(institutionId)),
                  ),
                ],
              ),
            ),
          ),
          data: (feeSchedules) {
            if (feeSchedules.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucuns frais de scolarité pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            final unitNames = <String, String>{
              for (final unit in unitsAsync.value ?? const <AcademicUnit>[]) unit.id: unit.name,
            };

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: feeSchedules.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final feeSchedule = feeSchedules[index];
                return _FeeScheduleCard(
                  institutionId: institutionId,
                  feeSchedule: feeSchedule,
                  scopeLabel: feeSchedule.academicUnitId == null
                      ? 'Tout l\'établissement'
                      : (unitNames[feeSchedule.academicUnitId] ?? '(classe)'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeeScheduleCard extends StatelessWidget {
  const _FeeScheduleCard({required this.institutionId, required this.feeSchedule, required this.scopeLabel});

  final String institutionId;
  final FeeSchedule feeSchedule;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/hub/school/fee-schedules/${feeSchedule.id}/edit', extra: institutionId),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feeSchedule.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  '${feeSchedule.period} · $scopeLabel',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text(formatGnf(feeSchedule.amount), style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
