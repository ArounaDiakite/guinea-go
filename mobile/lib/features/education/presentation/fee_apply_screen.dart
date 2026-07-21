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
import '../data/school_repository.dart';
import '../models/fee_schedule.dart';

/// Tap-to-apply, same interaction shape as picking a subject/teacher
/// elsewhere in this module rather than a separate list + submit
/// button - there's nothing else to configure, applying IS the action.
/// Only offers fee schedules that (a) actually apply to this student
/// (institution-wide, or scoped to their own academic unit) and (b)
/// haven't already been applied - the backend would 409 on a repeat,
/// this just avoids the round trip.
class FeeApplyScreen extends ConsumerWidget {
  const FeeApplyScreen({super.key, required this.institutionId, required this.studentId});

  final String institutionId;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeSchedulesAsync = ref.watch(feeSchedulesProvider(institutionId));
    final studentAsync = ref.watch(studentDetailProvider(studentId));
    final studentFeesAsync = ref.watch(studentFeesProvider(studentId));
    final textTheme = Theme.of(context).textTheme;

    final isLoading =
        feeSchedulesAsync.isLoading || studentAsync.isLoading || studentFeesAsync.isLoading;
    final error = feeSchedulesAsync.error ?? studentAsync.error ?? studentFeesAsync.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Appliquer des frais')),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
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
                        onPressed: () {
                          ref.invalidate(feeSchedulesProvider(institutionId));
                          ref.invalidate(studentDetailProvider(studentId));
                          ref.invalidate(studentFeesProvider(studentId));
                        },
                      ),
                    ],
                  ),
                ),
              )
            : Builder(
                builder: (context) {
                  final student = studentAsync.requireValue;
                  final appliedScheduleIds = studentFeesAsync.requireValue
                      .map((fee) => fee.feeScheduleId)
                      .toSet();

                  final available = feeSchedulesAsync.requireValue.where((schedule) {
                    if (appliedScheduleIds.contains(schedule.id)) return false;
                    if (schedule.academicUnitId == null) return true;
                    return schedule.academicUnitId == student.academicUnitId;
                  }).toList();

                  if (available.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Aucuns frais disponibles - tout a déjà été appliqué, ou créez '
                              'd\'abord des frais de scolarité.',
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: available.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _FeeScheduleTile(studentId: studentId, feeSchedule: available[index]),
                  );
                },
              ),
      ),
    );
  }
}

class _FeeScheduleTile extends ConsumerStatefulWidget {
  const _FeeScheduleTile({required this.studentId, required this.feeSchedule});

  final String studentId;
  final FeeSchedule feeSchedule;

  @override
  ConsumerState<_FeeScheduleTile> createState() => _FeeScheduleTileState();
}

class _FeeScheduleTileState extends ConsumerState<_FeeScheduleTile> {
  bool _isApplying = false;
  String? _errorMessage;

  Future<void> _apply() async {
    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      await ref.read(schoolRepositoryProvider).applyFeeSchedule(
        studentId: widget.studentId,
        feeScheduleId: widget.feeSchedule.id,
      );
      ref.invalidate(studentFeesProvider(widget.studentId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          onTap: _isApplying ? null : _apply,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: _isApplying
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.feeSchedule.name,
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      widget.feeSchedule.period,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                formatGnf(widget.feeSchedule.amount),
                style: textTheme.titleSmall?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppErrorBanner(message: _errorMessage!),
        ],
      ],
    );
  }
}
