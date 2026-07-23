import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/partners_controller.dart';
import '../models/pending_user.dart';

/// Every partner-ish role (company_owner, hotel_owner, event_organizer,
/// school_administrator, store_manager) self-registers inactive and
/// waits here until a system_administrator activates them - see
/// CLAUDE.md's RBAC table and AuthService.register_partner. Tapping a
/// row opens PartnerDetailScreen for the full record and the actual
/// activation action.
class PartnersListScreen extends ConsumerWidget {
  const PartnersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Comptes en attente de validation')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: pendingUsersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppErrorBanner(message: extractApiErrorMessage(error)),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Réessayer',
                  variant: AppButtonVariant.secondary,
                  expand: false,
                  onPressed: () => ref.invalidate(pendingUsersProvider),
                ),
              ],
            ),
          ),
          data: (users) {
            if (users.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task_alt_rounded, color: AppColors.textHint, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text('Aucun compte en attente de validation.', style: textTheme.titleMedium),
                  ],
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _PendingUserCard(user: users[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PendingUserCard extends StatelessWidget {
  const _PendingUserCard({required this.user});

  final PendingUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/partners/${user.id}', extra: user),
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
                Text(user.fullName, style: textTheme.titleSmall),
                Text(
                  '${partnerRoleLabel(user.role)} · ${user.email}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
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
