import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/event_organizer_controller.dart';
import '../models/event_booking.dart';

class EventBookingsReceivedScreen extends ConsumerWidget {
  const EventBookingsReceivedScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(eventBookingsReceivedProvider(eventId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Réservations reçues')),
      body: SafeArea(
        child: bookingsAsync.when(
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
                    onPressed: () => ref.invalidate(eventBookingsReceivedProvider(eventId)),
                  ),
                ],
              ),
            ),
          ),
          data: (bookings) {
            if (bookings.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_note_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune réservation reçue pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _ReceivedBookingCard(booking: bookings[index]),
            );
          },
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
  BookingStatus.pendingPayment: _StatusStyle('En attente de paiement', AppColors.accentDark, AppColors.accentLight),
  BookingStatus.confirmed: _StatusStyle('Confirmée', AppColors.secondaryDark, AppColors.secondaryLight),
  BookingStatus.cancelled: _StatusStyle('Annulée', AppColors.textSecondary, AppColors.surfaceVariant),
  BookingStatus.expired: _StatusStyle('Expirée', AppColors.error, AppColors.errorLight),
  BookingStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _ReceivedBookingCard extends StatelessWidget {
  const _ReceivedBookingCard({required this.booking});

  final EventBooking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyles[booking.status]!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.quantity} billet${booking.quantity > 1 ? 's' : ''}',
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(style.label, style: textTheme.labelSmall?.copyWith(color: style.foreground)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Spacer(),
              Text(formatGnf(booking.pricePaid), style: textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}
