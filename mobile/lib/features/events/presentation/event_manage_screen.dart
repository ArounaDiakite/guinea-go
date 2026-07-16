import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/event_detail_controller.dart';
import '../models/event.dart';

class EventManageScreen extends ConsumerWidget {
  const EventManageScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gérer l\'événement')),
      body: SafeArea(
        child: eventAsync.when(
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
                    onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                  ),
                ],
              ),
            ),
          ),
          data: (event) => _ManageMenu(event: event),
        ),
      ),
    );
  }
}

class _ManageMenu extends StatelessWidget {
  const _ManageMenu({required this.event});

  final Event event;

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
                child: const Icon(Icons.event_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.name, style: textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      event.isVerified ? 'Événement vérifié' : 'Vérification en attente',
                      style: textTheme.bodySmall?.copyWith(
                        color: event.isVerified ? AppColors.secondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Gestion', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.confirmation_number_outlined,
          label: 'Types de billets',
          subtitle: 'Catégories, prix, quantité',
          onTap: () => context.push('/hub/organizer/${event.id}/ticket-types'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.event_note_outlined,
          label: 'Réservations reçues',
          subtitle: 'Historique des réservations de l\'événement',
          onTap: () => context.push('/hub/organizer/${event.id}/bookings'),
        ),
      ],
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

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
                Text(label, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
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
