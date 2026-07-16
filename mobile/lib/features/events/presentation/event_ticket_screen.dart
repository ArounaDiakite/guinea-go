import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/event_ticket_controller.dart';
import '../models/event_booking_summary.dart';
import '../models/event_ticket.dart';

class EventTicketScreen extends ConsumerWidget {
  const EventTicketScreen({super.key, required this.summary});

  final EventBookingSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(eventTicketForBookingProvider(summary.booking.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Mon billet')),
      body: SafeArea(
        child: ticketAsync.when(
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
                    onPressed: () => ref.invalidate(eventTicketForBookingProvider(summary.booking.id)),
                  ),
                ],
              ),
            ),
          ),
          data: (ticket) => _TicketContent(summary: summary, ticket: ticket),
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

const _statusStyles = {
  EventTicketStatus.valid: _StatusStyle('Valide', AppColors.secondaryDark, AppColors.secondaryLight),
  EventTicketStatus.used: _StatusStyle('Utilisé', AppColors.textSecondary, AppColors.surfaceVariant),
  EventTicketStatus.cancelled: _StatusStyle('Annulé', AppColors.error, AppColors.errorLight),
  EventTicketStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _TicketContent extends StatelessWidget {
  const _TicketContent({required this.summary, required this.ticket});

  final EventBookingSummary summary;
  final EventTicket ticket;

  String _formatDateTime(DateTime dateTime) {
    const months = [
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
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '${dateTime.day} ${months[dateTime.month - 1]} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyles[ticket.status]!;
    final isValid = ticket.status == EventTicketStatus.valid;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      style.label,
                      style: textTheme.labelSmall?.copyWith(color: style.foreground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Opacity(
                opacity: isValid ? 1 : 0.35,
                child: QrImageView(
                  data: ticket.code,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ticket.code,
                style: textTheme.titleMedium?.copyWith(letterSpacing: 2),
              ),
              if (!isValid) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ticket.status == EventTicketStatus.used
                      ? 'Ce billet a déjà été utilisé à l\'entrée.'
                      : 'Ce billet a été annulé.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.eventName, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.sm),
              Text(summary.eventVenue, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDateTime(summary.eventStartDatetime),
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${summary.ticketCategoryLabel} · ${ticket.quantity} billet${ticket.quantity > 1 ? 's' : ''}',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(formatGnf(summary.booking.pricePaid), style: textTheme.titleSmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
