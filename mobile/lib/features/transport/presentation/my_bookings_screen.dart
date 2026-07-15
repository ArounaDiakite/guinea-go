import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/my_bookings_controller.dart';
import '../data/transport_repository.dart';
import '../models/booking.dart';
import '../models/booking_summary.dart';
import '../../../core/utils/currency.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  final _cancellingIds = <String>{};

  Future<void> _cancel(BookingSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text(
          '${summary.originCityName} → ${summary.destinationCityName}, siège ${summary.seatNumber}. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Retour')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Annuler la réservation')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingIds.add(summary.booking.id));

    try {
      await ref.read(transportRepositoryProvider).cancelBooking(summary.booking.id);
      ref.invalidate(myBookingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(summary.booking.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
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
                    onPressed: () => ref.invalidate(myBookingsProvider),
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
                      const Icon(Icons.confirmation_number_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune réservation pour le moment.', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Vos réservations de transport apparaîtront ici.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final summary = bookings[index];
                return _BookingCard(
                  summary: summary,
                  isCancelling: _cancellingIds.contains(summary.booking.id),
                  onCancel: () => _cancel(summary),
                );
              },
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.summary, required this.isCancelling, required this.onCancel});

  final BookingSummary summary;
  final bool isCancelling;
  final VoidCallback onCancel;

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
    final booking = summary.booking;
    final style = _statusStyles[booking.status]!;
    final canCancel = booking.status == BookingStatus.pendingPayment || booking.status == BookingStatus.confirmed;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(summary.companyName, style: textTheme.titleSmall),
              ),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${summary.originCityName} → ${summary.destinationCityName}',
                  style: textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatDateTime(summary.trip.departureDatetime),
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Siège ${summary.seatNumber}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(formatGnf(booking.pricePaid), style: textTheme.titleSmall),
            ],
          ),
          if (booking.status == BookingStatus.confirmed) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Voir le ticket',
              icon: Icons.qr_code_rounded,
              onPressed: () => context.push('/hub/transport/bookings/ticket', extra: summary),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Annuler la réservation',
              variant: AppButtonVariant.secondary,
              isLoading: isCancelling,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
