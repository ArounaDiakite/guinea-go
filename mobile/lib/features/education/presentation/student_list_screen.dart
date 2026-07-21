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
import '../models/student.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String? _academicUnitId;

  @override
  Widget build(BuildContext context) {
    final query = StudentListQuery(institutionId: widget.institutionId, academicUnitId: _academicUnitId);
    final studentsAsync = ref.watch(studentsProvider(query));
    final unitsAsync = ref.watch(academicUnitsProvider(widget.institutionId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Élèves')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/school/students/new', extra: widget.institutionId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            unitsAsync.when(
              data: (units) => _AcademicUnitFilter(
                units: units,
                selectedId: _academicUnitId,
                onSelected: (id) => setState(() => _academicUnitId = id),
              ),
              loading: () => const SizedBox(height: 0),
              error: (error, stackTrace) => const SizedBox(height: 0),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: studentsAsync.when(
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
                          onPressed: () => ref.invalidate(studentsProvider(query)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (students) {
                  if (students.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_outlined, color: AppColors.textHint, size: 48),
                            const SizedBox(height: AppSpacing.md),
                            Text('Aucun élève inscrit pour le moment.', style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _StudentCard(institutionId: widget.institutionId, student: students[index]),
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

class _AcademicUnitFilter extends StatelessWidget {
  const _AcademicUnitFilter({required this.units, required this.selectedId, required this.onSelected});

  final List<AcademicUnit> units;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox(height: 0);

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
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final unit in units)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(unit.name),
                selected: selectedId == unit.id,
                onSelected: (_) => onSelected(unit.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.institutionId, required this.student});

  final String institutionId;
  final Student student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/hub/school/students/${student.id}/edit', extra: institutionId),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                if (student.guardianName != null && student.guardianName!.isNotEmpty)
                  Text(
                    'Tuteur : ${student.guardianName}',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Frais de scolarité',
            icon: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/hub/school/students/${student.id}/fees', extra: institutionId),
          ),
          IconButton(
            tooltip: 'Notes',
            icon: const Icon(Icons.grade_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/hub/school/students/${student.id}/grades', extra: institutionId),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
