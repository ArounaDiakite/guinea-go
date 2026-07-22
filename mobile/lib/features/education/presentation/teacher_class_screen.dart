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
import '../models/timeslot.dart';

/// A teacher's view of one of their assigned classes: the roster
/// (read-only - students:view_own has no write counterpart) and the
/// class's weekly schedule, where only the teacher's own slots (see
/// ScheduleItem.teacherId) get an attendance-entry shortcut into the
/// same AttendanceEntryScreen school_administrator uses - the backend
/// enforces the "own slot only" rule server-side either way (see
/// EducationAccess.ensure_teacher_owns_timeslot), this just avoids
/// offering a control that would 403.
class TeacherClassScreen extends ConsumerWidget {
  const TeacherClassScreen({
    super.key,
    required this.institutionId,
    required this.teacherId,
    required this.academicUnitId,
  });

  final String institutionId;
  final String teacherId;
  final String academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ma classe'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Élèves'),
              Tab(text: 'Emploi du temps'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _StudentRoster(institutionId: institutionId, academicUnitId: academicUnitId),
              _TeacherSchedule(
                institutionId: institutionId,
                teacherId: teacherId,
                academicUnitId: academicUnitId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRoster extends ConsumerWidget {
  const _StudentRoster({required this.institutionId, required this.academicUnitId});

  final String institutionId;
  final String academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = StudentListQuery(institutionId: institutionId, academicUnitId: academicUnitId);
    final studentsAsync = ref.watch(studentsProvider(query));
    final textTheme = Theme.of(context).textTheme;

    return studentsAsync.when(
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
                  Text('Aucun élève dans cette classe.', style: textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: students.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final student = students[index];
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      student.fullName,
                      style: textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TeacherSchedule extends ConsumerWidget {
  const _TeacherSchedule({
    required this.institutionId,
    required this.teacherId,
    required this.academicUnitId,
  });

  final String institutionId;
  final String teacherId;
  final String academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider(academicUnitId));
    final textTheme = Theme.of(context).textTheme;

    return scheduleAsync.when(
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
                onPressed: () => ref.invalidate(scheduleProvider(academicUnitId)),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.textHint, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aucun créneau enregistré pour le moment.', style: textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        final byDay = <DayOfWeek, List<ScheduleItem>>{};
        for (final item in items) {
          byDay.putIfAbsent(item.dayOfWeek, () => []).add(item);
        }
        final sortedDays = byDay.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
        for (final day in sortedDays) {
          byDay[day]!.sort(
            (a, b) =>
                (a.startTime.hour * 60 + a.startTime.minute).compareTo(b.startTime.hour * 60 + b.startTime.minute),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
            for (final day in sortedDays) ...[
              Text(day.label, style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
              const SizedBox(height: AppSpacing.sm),
              for (final item in byDay[day]!) ...[
                _TeacherScheduleItemCard(
                  institutionId: institutionId,
                  academicUnitId: academicUnitId,
                  isOwnSlot: item.teacherId == teacherId,
                  item: item,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class _TeacherScheduleItemCard extends StatelessWidget {
  const _TeacherScheduleItemCard({
    required this.institutionId,
    required this.academicUnitId,
    required this.isOwnSlot,
    required this.item,
  });

  final String institutionId;
  final String academicUnitId;
  final bool isOwnSlot;
  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimeOfDay(item.startTime),
                  style: textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                Text(_formatTimeOfDay(item.endTime), style: textTheme.labelSmall?.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.subjectName, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  item.teacherName,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (isOwnSlot)
            IconButton(
              tooltip: 'Saisir les présences',
              icon: const Icon(Icons.how_to_reg_outlined, color: AppColors.primary),
              onPressed: () => context.push(
                '/hub/teacher/classes/$academicUnitId/timeslots/${item.id}/attendance',
                extra: institutionId,
              ),
            ),
        ],
      ),
    );
  }
}
