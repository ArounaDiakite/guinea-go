import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/trip_detail_controller.dart';
import '../data/transport_repository.dart';
import '../models/trip_detail.dart';
import '../models/trip_seat.dart';
import '../utils/currency.dart';
import '../utils/seat_pricing.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.tripId, required this.seat});

  final String tripId;
  final TripSeat seat;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _confirm() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final booking = await ref
          .read(transportRepositoryProvider)
          .createBooking(tripId: widget.tripId, seatId: widget.seat.seatId);
      if (mounted) {
        context.push('/hub/transport/trips/${widget.tripId}/booking/payment', extra: booking);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Récapitulatif')),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppErrorBanner(message: extractApiErrorMessage(error)),
            ),
          ),
          data: (detail) => _RecapBody(
            detail: detail,
            seat: widget.seat,
            isSubmitting: _isSubmitting,
            errorMessage: _errorMessage,
            onConfirm: _confirm,
          ),
        ),
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({
    required this.detail,
    required this.seat,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onConfirm,
  });

  final TripDetail detail;
  final TripSeat seat;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onConfirm;

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static const _seatTypeLabels = {
    SeatType.window: 'Fenêtre',
    SeatType.aisle: 'Couloir',
    SeatType.standard: 'Standard',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trip = detail.trip;
    final estimatedPrice = estimateSeatPrice(trip.price, seat.seatType);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.company.name, style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(detail.originCityName, style: textTheme.titleSmall),
                              Text(_formatTime(trip.departureDatetime), style: textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_right_alt_rounded, color: AppColors.textHint),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(detail.destinationCityName, style: textTheme.titleSmall),
                              if (trip.estimatedArrivalDatetime != null)
                                Text(_formatTime(trip.estimatedArrivalDatetime!), style: textTheme.bodyMedium),
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
                    _RecapRow(label: 'Siège', value: '${seat.seatNumber} · ${_seatTypeLabels[seat.seatType]}'),
                    const Divider(height: AppSpacing.xl),
                    _RecapRow(label: 'Bus', value: '${detail.bus.brand} ${detail.bus.model}'),
                    const Divider(height: AppSpacing.xl),
                    _RecapRow(label: 'Prix', value: formatGnf(estimatedPrice), emphasize: true),
                  ],
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorBanner(message: errorMessage!),
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
              isLoading: isSubmitting,
              onPressed: onConfirm,
            ),
          ),
        ),
      ],
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Text(
          value,
          style: emphasize ? textTheme.titleLarge?.copyWith(color: AppColors.primary) : textTheme.bodyLarge,
        ),
      ],
    );
  }
}
