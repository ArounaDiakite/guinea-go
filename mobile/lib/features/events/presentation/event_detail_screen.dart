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
import '../application/event_detail_controller.dart';
import '../models/event.dart';
import '../models/event_booking_selection.dart';
import '../models/ticket_type.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de l\'événement')),
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
                    onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                  ),
                ],
              ),
            ),
          ),
          data: (event) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _EventInfoCard(event: event),
              const SizedBox(height: AppSpacing.lg),
              Text('Types de billets', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _TicketTypesSection(eventId: eventId, eventName: event.name),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _formatDateTime(DateTime dateTime) {
  final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  return '${dateTime.day} ${_months[dateTime.month - 1]} ${dateTime.year} · $time';
}

class _EventInfoCard extends ConsumerWidget {
  const _EventInfoCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final reviewAsync = ref.watch(eventReviewSummaryProvider(event.id));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(event.name, style: textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
              ),
              reviewAsync.when(
                data: (summary) {
                  final (average, count) = summary;
                  if (average == null) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.accentDark, size: 20),
                      const SizedBox(width: 2),
                      Text(
                        '${average.toStringAsFixed(1)} ($count)',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.accentDark),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              event.category.label,
              style: textTheme.labelSmall?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  event.venue,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${_formatDateTime(event.startDatetime)} → ${_formatDateTime(event.endDatetime)}',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(event.description!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _TicketTypesSection extends ConsumerWidget {
  const _TicketTypesSection({required this.eventId, required this.eventName});

  final String eventId;
  final String eventName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketTypesAsync = ref.watch(eventTicketTypesProvider(eventId));

    return ticketTypesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Column(
        children: [
          AppErrorBanner(message: extractApiErrorMessage(error)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réessayer',
            variant: AppButtonVariant.secondary,
            onPressed: () => ref.invalidate(eventTicketTypesProvider(eventId)),
          ),
        ],
      ),
      data: (ticketTypes) {
        if (ticketTypes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'Aucun billet disponible pour cet événement.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final ticketType in ticketTypes) ...[
              _TicketTypeCard(ticketType: ticketType, eventName: eventName),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _TicketTypeCard extends StatefulWidget {
  const _TicketTypeCard({required this.ticketType, required this.eventName});

  final TicketType ticketType;
  final String eventName;

  @override
  State<_TicketTypeCard> createState() => _TicketTypeCardState();
}

class _TicketTypeCardState extends State<_TicketTypeCard> {
  int _quantity = 1;

  static const _maxPerBooking = 20;

  int get _maxQuantity {
    final cap = widget.ticketType.quantityAvailable < _maxPerBooking
        ? widget.ticketType.quantityAvailable
        : _maxPerBooking;
    return cap < 1 ? 0 : cap;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ticketType = widget.ticketType;
    final soldOut = ticketType.quantityAvailable <= 0;
    final total = ticketType.basePrice * _quantity;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticketType.category.label,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
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
              Icon(
                soldOut ? Icons.event_busy_rounded : Icons.confirmation_number_outlined,
                size: 16,
                color: soldOut ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  soldOut ? 'Complet' : '${ticketType.quantityAvailable} restant(s)',
                  style: textTheme.bodySmall?.copyWith(color: soldOut ? AppColors.error : AppColors.textSecondary),
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
          if (!soldOut) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('Quantité', style: textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                ),
                Text('$_quantity', style: textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Réserver · ${formatGnf(total)}',
              onPressed: () => context.push(
                '/hub/events/${ticketType.eventId}/booking',
                extra: EventBookingSelection(
                  ticketType: ticketType,
                  quantity: _quantity,
                  eventName: widget.eventName,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
