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
import '../data/hotel_repository.dart';
import '../models/hotel_booking_selection.dart';
import '../models/room.dart';

class HotelBookingScreen extends ConsumerStatefulWidget {
  const HotelBookingScreen({super.key, required this.selection});

  final HotelBookingSelection selection;

  @override
  ConsumerState<HotelBookingScreen> createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends ConsumerState<HotelBookingScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _months = [
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

  String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

  Future<void> _confirm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final room = widget.selection.room;
    final stay = widget.selection.stay;

    try {
      final booking = await ref.read(hotelRepositoryProvider).createBooking(
        roomId: room.id,
        checkIn: stay.checkIn,
        checkOut: stay.checkOut,
      );
      if (mounted) {
        context.push(
          '/hub/hotels/${room.hotelId}/booking/payment',
          extra: PaymentRequest(
            bookingId: booking.id,
            pricePaid: booking.pricePaid,
            bookingType: PaymentBookingType.hotel,
            confirmedRoute: '/hub/hotels/bookings',
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
    final room = widget.selection.room;
    final stay = widget.selection.stay;
    final total = room.basePrice * stay.nights;

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
                        Text('${room.roomType.label} · Chambre ${room.roomNumber}', style: textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Arrivée', style: textTheme.labelMedium),
                                  Text(_formatDate(stay.checkIn), style: textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_right_alt_rounded, color: AppColors.textHint),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Départ', style: textTheme.labelMedium),
                                  Text(_formatDate(stay.checkOut), style: textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RecapRow(label: 'Prix par nuit', value: formatGnf(room.basePrice)),
                        const Divider(height: AppSpacing.xl),
                        _RecapRow(label: 'Nuits', value: '${stay.nights}'),
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
