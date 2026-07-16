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
import '../application/event_organizer_controller.dart';
import '../models/ticket_type.dart';

class EventTicketTypesScreen extends ConsumerWidget {
  const EventTicketTypesScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketTypesAsync = ref.watch(eventTicketTypesManagedProvider(eventId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Types de billets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/organizer/$eventId/ticket-types/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: ticketTypesAsync.when(
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
                    onPressed: () => ref.invalidate(eventTicketTypesManagedProvider(eventId)),
                  ),
                ],
              ),
            ),
          ),
          data: (ticketTypes) {
            if (ticketTypes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.confirmation_number_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun type de billet enregistré pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: ticketTypes.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _TicketTypeCard(ticketType: ticketTypes[index]),
            );
          },
        ),
      ),
    );
  }
}

class _TicketTypeCard extends StatelessWidget {
  const _TicketTypeCard({required this.ticketType});

  final TicketType ticketType;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sold = ticketType.quantityTotal - ticketType.quantityAvailable;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ticketType.category.label, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  formatGnf(ticketType.basePrice),
                  style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '$sold vendu${sold > 1 ? 's' : ''} sur ${ticketType.quantityTotal}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (ticketType.description != null && ticketType.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              ticketType.description!,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
