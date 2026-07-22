import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/school_controller.dart';
import '../models/timeslot.dart';

/// Read-only weekly timetable for the student's own academic unit -
/// same data/grouping as AcademicUnitScheduleScreen (school_
/// administrator's version) minus the "add slot"/"edit"/"take
/// attendance" affordances a student has no permission to use.
class StudentScheduleScreen extends ConsumerWidget {
  const StudentScheduleScreen({super.key, required this.academicUnitId});

  final String academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider(academicUnitId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Emploi du temps')),
      body: SafeArea(
        child: scheduleAsync.when(
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
                (a, b) => (a.startTime.hour * 60 + a.startTime.minute).compareTo(
                  b.startTime.hour * 60 + b.startTime.minute,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                for (final day in sortedDays) ...[
                  Text(day.label, style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final item in byDay[day]!) ...[
                    _ScheduleItemCard(item: item),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class _ScheduleItemCard extends StatelessWidget {
  const _ScheduleItemCard({required this.item});

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
        ],
      ),
    );
  }
}
