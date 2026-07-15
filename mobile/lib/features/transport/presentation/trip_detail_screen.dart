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
import '../models/trip.dart';
import '../models/trip_detail.dart';
import '../models/trip_seat.dart';
import '../../../core/utils/currency.dart';
import '../utils/seat_pricing.dart';
import 'seat_map.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  TripSeat? _selectedSeat;

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
    final detailAsync = ref.watch(tripDetailProvider(widget.tripId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Détails du trajet')),
      body: SafeArea(
        child: detailAsync.when(
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
                    onPressed: () => ref.invalidate(tripDetailProvider(widget.tripId)),
                  ),
                ],
              ),
            ),
          ),
          data: (detail) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _RouteCard(detail: detail, formatDateTime: _formatDateTime),
                    const SizedBox(height: AppSpacing.md),
                    _BusAndDriverCard(detail: detail),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Choisissez votre siège', style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    _SeatSection(
                      tripId: widget.tripId,
                      selectedSeat: _selectedSeat,
                      onSeatTap: (seat) => setState(() => _selectedSeat = seat),
                    ),
                  ],
                ),
              ),
              _BookingBar(
                trip: detail.trip,
                tripId: widget.tripId,
                selectedSeat: _selectedSeat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.detail, required this.formatDateTime});

  final TripDetail detail;
  final String Function(DateTime) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trip = detail.trip;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.company.name, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detail.originCityName, style: textTheme.titleSmall),
                    Text(
                      detail.originStationName,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(formatDateTime(trip.departureDatetime), style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.arrow_right_alt_rounded, color: AppColors.textHint),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(detail.destinationCityName, style: textTheme.titleSmall),
                    Text(
                      detail.destinationStationName,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (trip.estimatedArrivalDatetime != null)
                      Text(formatDateTime(trip.estimatedArrivalDatetime!), style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${trip.availableSeats} places disponibles',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text('À partir de ${formatGnf(trip.price)}', style: textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusAndDriverCard extends StatelessWidget {
  const _BusAndDriverCard({required this.detail});

  final TripDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bus = detail.bus;
    final driver = detail.driver;

    final amenities = <(IconData, String)>[
      if (bus.airConditioning) (Icons.ac_unit_rounded, 'Climatisation'),
      if (bus.wifi) (Icons.wifi_rounded, 'Wifi'),
      if (bus.usbCharging) (Icons.usb_rounded, 'Prises USB'),
      if (bus.toilet) (Icons.wc_rounded, 'Toilettes'),
      if (bus.television) (Icons.tv_rounded, 'Télévision'),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('${bus.brand} ${bus.model} · ${bus.busType}', style: textTheme.titleSmall),
              ),
            ],
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (icon, label) in amenities)
                  Chip(
                    avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
                    label: Text(label),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${driver.fullName} · ${driver.yearsOfExperience} ans d\'expérience',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatSection extends ConsumerWidget {
  const _SeatSection({required this.tripId, required this.selectedSeat, required this.onSeatTap});

  final String tripId;
  final TripSeat? selectedSeat;
  final ValueChanged<TripSeat> onSeatTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(tripSeatsProvider(tripId));

    return seatsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Column(
        children: [
          AppErrorBanner(message: 'Impossible de charger le plan des sièges.'),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réessayer',
            variant: AppButtonVariant.secondary,
            onPressed: () => ref.invalidate(tripSeatsProvider(tripId)),
          ),
        ],
      ),
      data: (seats) => SeatMap(
        seats: seats,
        selectedSeatId: selectedSeat?.seatId,
        onSeatTap: onSeatTap,
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.trip, required this.tripId, required this.selectedSeat});

  final Trip trip;
  final String tripId;
  final TripSeat? selectedSeat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final estimatedPrice = selectedSeat != null ? estimateSeatPrice(trip.price, selectedSeat!.seatType) : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedSeat != null ? 'Siège ${selectedSeat!.seatNumber}' : 'Aucun siège sélectionné',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    estimatedPrice != null ? formatGnf(estimatedPrice) : '—',
                    style: textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Continuer',
                onPressed: selectedSeat == null
                    ? null
                    : () => context.push('/hub/transport/trips/$tripId/booking', extra: selectedSeat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
