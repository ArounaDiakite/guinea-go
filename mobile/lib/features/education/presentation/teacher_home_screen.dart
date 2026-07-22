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
import '../models/teacher.dart';

/// A teacher's landing screen: their own profile (GET /teachers/me)
/// resolves which institution and academic units they're assigned to,
/// then one card per assigned class opens TeacherClassScreen (students
/// + schedule + attendance entry, all scoped to that class).
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(myTeacherProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes classes')),
      body: SafeArea(
        child: teacherAsync.when(
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
                    onPressed: () => ref.invalidate(myTeacherProfileProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (teacher) => _TeacherClassList(teacher: teacher),
        ),
      ),
    );
  }
}

class _TeacherClassList extends ConsumerWidget {
  const _TeacherClassList({required this.teacher});

  final Teacher teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    if (teacher.academicUnitIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.class_outlined, color: AppColors.textHint, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aucune classe ne vous est encore assignée.',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: teacher.academicUnitIds.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final academicUnitId = teacher.academicUnitIds[index];
        return _AcademicUnitCard(
          institutionId: teacher.institutionId,
          teacherId: teacher.id,
          academicUnitId: academicUnitId,
        );
      },
    );
  }
}

class _AcademicUnitCard extends ConsumerWidget {
  const _AcademicUnitCard({
    required this.institutionId,
    required this.teacherId,
    required this.academicUnitId,
  });

  final String institutionId;
  final String teacherId;
  final String academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitAsync = ref.watch(academicUnitDetailProvider(academicUnitId));
    final textTheme = Theme.of(context).textTheme;

    return unitAsync.when(
      loading: () => const AppCard(child: LinearProgressIndicator()),
      error: (error, stackTrace) => AppCard(
        child: Text('Classe indisponible (${academicUnitId.substring(0, 6)})', style: textTheme.bodyMedium),
      ),
      data: (unit) => AppCard(
        onTap: () => context.push(
          '/hub/teacher/classes/$academicUnitId',
          extra: {'institutionId': institutionId, 'teacherId': teacherId},
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
      ),
    );
  }
}
