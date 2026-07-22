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
import '../models/student.dart';

/// A student's landing screen: their own profile (GET /students/me)
/// resolves institution/academic unit, then shortcuts into everything
/// they can see - all read-only, matching their permission set
/// (timeslots:view_self, grades:view_self, report_card:view_self,
/// attendance:view_self, fees:view_self - no *:manage anywhere).
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(myStudentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: SafeArea(
        child: studentAsync.when(
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
                    onPressed: () => ref.invalidate(myStudentProfileProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (student) => _StudentMenu(student: student),
        ),
      ),
    );
  }
}

class _StudentMenu extends StatelessWidget {
  const _StudentMenu({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  student.fullName,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _MenuTile(
          icon: Icons.calendar_month_outlined,
          label: 'Emploi du temps',
          subtitle: 'Mes cours de la semaine',
          onTap: () => context.push('/hub/student/schedule', extra: student.academicUnitId),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuTile(
          icon: Icons.grade_outlined,
          label: 'Notes et bulletin',
          subtitle: 'Mes notes par matière et ma moyenne',
          onTap: () => context.push('/hub/student/grades', extra: student.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuTile(
          icon: Icons.how_to_reg_outlined,
          label: 'Présences',
          subtitle: 'Historique de mes présences',
          onTap: () => context.push('/hub/student/attendance', extra: student.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          label: 'Frais de scolarité',
          subtitle: 'Mes frais et paiements',
          onTap: () => context.push('/hub/student/fees', extra: student.id),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.subtitle, required this.onTap});

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  subtitle,
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
