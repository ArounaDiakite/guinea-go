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
import '../models/subject.dart';
import 'grade_form_screen.dart';

class GradeListScreen extends ConsumerStatefulWidget {
  const GradeListScreen({super.key, required this.institutionId, required this.studentId});

  final String institutionId;
  final String studentId;

  @override
  ConsumerState<GradeListScreen> createState() => _GradeListScreenState();
}

class _GradeListScreenState extends ConsumerState<GradeListScreen> {
  Period? _period;

  @override
  Widget build(BuildContext context) {
    final query = GradesQuery(studentId: widget.studentId, period: _period);
    final gradesAsync = ref.watch(gradesProvider(query));
    final subjectsAsync = ref.watch(subjectsProvider(widget.institutionId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Bulletin',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => context.push('/hub/school/students/${widget.studentId}/report-card'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/hub/school/students/${widget.studentId}/grades/form',
          extra: GradeFormArgs(institutionId: widget.institutionId, existingGrade: null),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une note'),
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

                  final subjectNames = <String, String>{
                    for (final subject in subjectsAsync.value ?? const <Subject>[]) subject.id: subject.name,
                  };

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: grades.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final grade = grades[index];
                      return _GradeCard(
                        institutionId: widget.institutionId,
                        studentId: widget.studentId,
                        grade: grade,
                        subjectName: subjectNames[grade.subjectId] ?? '(matière)',
                      );
                    },
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
  const _GradeCard({
    required this.institutionId,
    required this.studentId,
    required this.grade,
    required this.subjectName,
  });

  final String institutionId;
  final String studentId;
  final Grade grade;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push(
        '/hub/school/students/$studentId/grades/form',
        extra: GradeFormArgs(institutionId: institutionId, existingGrade: grade),
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subjectName, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  '${grade.period.label} · coefficient ${_formatNumber(grade.coefficient)}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Text('${_formatNumber(grade.value)}/20', style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
