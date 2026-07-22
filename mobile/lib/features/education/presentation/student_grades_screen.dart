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
import '../models/grade.dart';

/// Read-only counterpart of GradeListScreen (school_administrator's
/// version) - same data (grades:view_self), no "add grade" FAB and no
/// tap-to-edit, since a student only has grades:view_self, not
/// grades:manage. Subject names aren't resolved here the way
/// GradeListScreen's admin version does (that needs subjects:view_own/
/// manage the student role doesn't have) - each Grade only shows what
/// grades:view_self itself returns.
class StudentGradesScreen extends ConsumerStatefulWidget {
  const StudentGradesScreen({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<StudentGradesScreen> createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends ConsumerState<StudentGradesScreen> {
  Period? _period;

  @override
  Widget build(BuildContext context) {
    final query = GradesQuery(studentId: widget.studentId, period: _period);
    final gradesAsync = ref.watch(gradesProvider(query));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes notes'),
        actions: [
          IconButton(
            tooltip: 'Bulletin',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => context.push('/hub/student/report-card', extra: widget.studentId),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _PeriodFilter(selected: _period, onSelected: (period) => setState(() => _period = period)),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: gradesAsync.when(
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
                          onPressed: () => ref.invalidate(gradesProvider(query)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (grades) {
                  if (grades.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.grade_outlined, color: AppColors.textHint, size: 48),
                            const SizedBox(height: AppSpacing.md),
                            Text('Aucune note enregistrée pour le moment.', style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: grades.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _GradeCard(grade: grades[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({required this.selected, required this.onSelected});

  final Period? selected;
  final ValueChanged<Period?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: const Text('Toutes'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final period in Period.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(period.apiValue),
                selected: selected == period,
                onSelected: (_) => onSelected(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.grade});

  final Grade grade;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.grade_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${grade.period.label} · coefficient ${_formatNumber(grade.coefficient)}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Text('${_formatNumber(grade.value)}/20', style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
