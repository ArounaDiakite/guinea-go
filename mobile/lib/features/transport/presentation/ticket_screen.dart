import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/ticket_controller.dart';
import '../models/booking_summary.dart';
import '../models/ticket.dart';
import '../utils/currency.dart';

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.summary});

  final BookingSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(ticketForBookingProvider(summary.booking.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Mon ticket')),
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
                    onPressed: () => ref.invalidate(ticketForBookingProvider(summary.booking.id)),
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
  TicketStatus.valid: _StatusStyle('Valide', AppColors.secondaryDark, AppColors.secondaryLight),
  TicketStatus.used: _StatusStyle('Utilisé', AppColors.textSecondary, AppColors.surfaceVariant),
  TicketStatus.cancelled: _StatusStyle('Annulé', AppColors.error, AppColors.errorLight),
  TicketStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _TicketContent extends StatelessWidget {
  const _TicketContent({required this.summary, required this.ticket});

  final BookingSummary summary;
  final Ticket ticket;

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
    final isValid = ticket.status == TicketStatus.valid;

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
                  ticket.status == TicketStatus.used
                      ? 'Ce ticket a déjà été utilisé à l\'embarquement.'
                      : 'Ce ticket a été annulé.',
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
              Text(summary.companyName, style: textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${summary.originCityName} → ${summary.destinationCityName}',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatDateTime(summary.trip.departureDatetime),
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Siège ${summary.seatNumber}',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
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
