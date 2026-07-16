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
import '../../payments/models/payment.dart';
import '../data/event_repository.dart';
import '../models/event_booking_selection.dart';
import '../models/ticket_type.dart';

class EventBookingScreen extends ConsumerStatefulWidget {
  const EventBookingScreen({super.key, required this.selection});

  final EventBookingSelection selection;

  @override
  ConsumerState<EventBookingScreen> createState() => _EventBookingScreenState();
}

class _EventBookingScreenState extends ConsumerState<EventBookingScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _confirm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final ticketType = widget.selection.ticketType;

    try {
      final booking = await ref.read(eventRepositoryProvider).createBooking(
        ticketTypeId: ticketType.id,
        quantity: widget.selection.quantity,
      );
      if (mounted) {
        context.push(
          '/hub/events/${ticketType.eventId}/booking/payment',
          extra: PaymentRequest(
            bookingId: booking.id,
            pricePaid: booking.pricePaid,
            bookingType: PaymentBookingType.event,
            confirmedRoute: '/hub/events/bookings',
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selection = widget.selection;
    final ticketType = selection.ticketType;
    final total = ticketType.basePrice * selection.quantity;

    return Scaffold(
      appBar: AppBar(title: const Text('Récapitulatif')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selection.eventName,
                          style: textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${ticketType.category.label} · ${selection.quantity} billet${selection.quantity > 1 ? 's' : ''}',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RecapRow(label: 'Prix unitaire', value: formatGnf(ticketType.basePrice)),
                        const Divider(height: AppSpacing.xl),
                        _RecapRow(label: 'Quantité', value: '${selection.quantity}'),
                        const Divider(height: AppSpacing.xl),
                        _RecapRow(label: 'Total', value: formatGnf(total), emphasize: true),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppErrorBanner(message: _errorMessage!),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: AppButton(
                  label: 'Confirmer la réservation',
                  isLoading: _isSubmitting,
                  onPressed: _confirm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          flex: 2,
          child: Text(
            value,
            style: emphasize ? textTheme.titleLarge?.copyWith(color: AppColors.primary) : textTheme.bodyLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
