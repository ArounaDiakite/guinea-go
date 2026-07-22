import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../models/student_fee.dart';

/// Read-only counterpart of StudentFeesScreen (school_administrator's
/// version) - same data (fees:view_self), no "apply fee schedule" FAB
/// and no tap-to-pay, since a student only has fees:view_self, not
/// fees:manage/payments:manage.
class StudentFeesViewScreen extends ConsumerWidget {
  const StudentFeesViewScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentFeesAsync = ref.watch(studentFeesProvider(studentId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Frais de scolarité')),
      body: SafeArea(
        child: studentFeesAsync.when(
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
                    onPressed: () => ref.invalidate(studentFeesProvider(studentId)),
                  ),
                ],
              ),
            ),
          ),
          data: (studentFees) {
            if (studentFees.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucuns frais appliqués pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: studentFees.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _StudentFeeCard(studentFee: studentFees[index]),
            );
          },
        ),
      ),
    );
  }
}

class _StudentFeeCard extends StatelessWidget {
  const _StudentFeeCard({required this.studentFee});

  final StudentFee studentFee;

  Color _statusColor() => switch (studentFee.status) {
    StudentFeeStatus.paid => AppColors.success,
    StudentFeeStatus.partial => AppColors.warning,
    StudentFeeStatus.unpaid => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  studentFee.feeScheduleName,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  studentFee.status.label,
                  style: textTheme.labelSmall?.copyWith(color: _statusColor(), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(studentFee.period, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatGnf(studentFee.amountPaid)} / ${formatGnf(studentFee.amountDue)}',
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (studentFee.amountRemaining > 0)
                Text(
                  'Reste ${formatGnf(studentFee.amountRemaining)}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
