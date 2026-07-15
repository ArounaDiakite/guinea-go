import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/trip_seat.dart';

/// Bus seats are generated in row-major order in groups of 4 (window,
/// aisle, aisle, window - confirmed against the real API response,
/// there's no row/column field to lay this out from directly) - the
/// last row may be short if seat_capacity isn't a multiple of 4.
class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.seats,
    required this.selectedSeatId,
    required this.onSeatTap,
  });

  final List<TripSeat> seats;
  final String? selectedSeatId;
  final ValueChanged<TripSeat> onSeatTap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<TripSeat>>[];
    for (var i = 0; i < seats.length; i += 4) {
      rows.add(seats.sublist(i, i + 4 > seats.length ? seats.length : i + 4));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Column(
            children: [
              const Icon(Icons.airline_seat_recline_normal_rounded, color: AppColors.textHint),
              Text('Avant du bus', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            children: [
              for (final row in rows) _SeatRow(row: row, selectedSeatId: selectedSeatId, onSeatTap: onSeatTap),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _SeatLegend(),
      ],
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({required this.row, required this.selectedSeatId, required this.onSeatTap});

  final List<TripSeat> row;
  final String? selectedSeatId;
  final ValueChanged<TripSeat> onSeatTap;

  @override
  Widget build(BuildContext context) {
    final left = row.take(2).toList();
    final right = row.length > 2 ? row.sublist(2) : <TripSeat>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final seat in left)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _SeatBox(seat: seat, selected: seat.seatId == selectedSeatId, onTap: onSeatTap),
            ),
          const SizedBox(width: AppSpacing.lg),
          for (final seat in right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _SeatBox(seat: seat, selected: seat.seatId == selectedSeatId, onTap: onSeatTap),
            ),
        ],
      ),
    );
  }
}

class _SeatBox extends StatelessWidget {
  const _SeatBox({required this.seat, required this.selected, required this.onTap});

  final TripSeat seat;
  final bool selected;
  final ValueChanged<TripSeat> onTap;

  @override
  Widget build(BuildContext context) {
    final isAvailable = seat.status == SeatStatus.available;

    Color background;
    Color foreground;
    Color? borderColor;

    if (selected) {
      background = AppColors.primary;
      foreground = AppColors.textOnPrimary;
    } else if (seat.status == SeatStatus.maintenance) {
      background = AppColors.surfaceVariant;
      foreground = AppColors.textHint;
    } else if (seat.status == SeatStatus.reserved) {
      background = AppColors.textHint.withValues(alpha: 0.25);
      foreground = AppColors.textSecondary;
    } else {
      background = AppColors.surface;
      foreground = AppColors.textPrimary;
      borderColor = AppColors.border;
    }

    return InkWell(
      onTap: isAvailable ? () => onTap(seat) : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: seat.status == SeatStatus.maintenance
            ? const Icon(Icons.build_rounded, size: 16, color: AppColors.textHint)
            : Text(
                seat.seatNumber,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: const [
        _LegendItem(color: AppColors.surface, borderColor: AppColors.border, label: 'Disponible'),
        _LegendItem(color: AppColors.primary, label: 'Sélectionné'),
        _LegendItem(color: AppColors.textHint, label: 'Réservé'),
        _LegendItem(color: AppColors.surfaceVariant, borderColor: AppColors.border, label: 'Maintenance'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, this.borderColor, required this.label});

  final Color color;
  final Color? borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
