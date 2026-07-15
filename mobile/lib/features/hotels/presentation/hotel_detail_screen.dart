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
import '../application/hotel_detail_controller.dart';
import '../models/hotel.dart';
import '../models/hotel_booking_selection.dart';
import '../models/hotel_rooms_query.dart';
import '../models/hotel_stay.dart';
import '../models/room.dart';

class HotelDetailScreen extends ConsumerWidget {
  const HotelDetailScreen({super.key, required this.hotelId, required this.stay});

  final String hotelId;
  final HotelStay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelAsync = ref.watch(hotelDetailProvider(hotelId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détails de l\'hôtel')),
      body: SafeArea(
        child: hotelAsync.when(
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
                    onPressed: () => ref.invalidate(hotelDetailProvider(hotelId)),
                  ),
                ],
              ),
            ),
          ),
          data: (hotel) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _HotelInfoCard(hotel: hotel),
              const SizedBox(height: AppSpacing.lg),
              Text('Chambres disponibles', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${stay.nights} nuit${stay.nights > 1 ? 's' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              _RoomsSection(hotelId: hotelId, stay: stay),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelInfoCard extends ConsumerWidget {
  const _HotelInfoCard({required this.hotel});

  final Hotel hotel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final reviewAsync = ref.watch(hotelReviewSummaryProvider(hotel.id));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(hotel.name, style: textTheme.headlineSmall)),
              reviewAsync.when(
                data: (summary) {
                  final (average, count) = summary;
                  if (average == null) return const SizedBox.shrink();
                  return Row(
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(hotel.address, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ),
            ],
          ),
          if (hotel.description != null && hotel.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(hotel.description!, style: textTheme.bodyMedium),
          ],
          if (hotel.amenities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final amenity in hotel.amenities) Chip(label: Text(amenity)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(hotel.phone, style: textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(hotel.email, style: textTheme.bodyMedium),
            ],
          ),
          if (hotel.website != null && hotel.website!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.public_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(hotel.website!, style: textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomsSection extends ConsumerWidget {
  const _RoomsSection({required this.hotelId, required this.stay});

  final String hotelId;
  final HotelStay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = HotelRoomsQuery(hotelId: hotelId, checkIn: stay.checkIn, checkOut: stay.checkOut);
    final roomsAsync = ref.watch(hotelAvailableRoomsProvider(query));

    return roomsAsync.when(
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
            onPressed: () => ref.invalidate(hotelAvailableRoomsProvider(query)),
          ),
        ],
      ),
      data: (rooms) {
        if (rooms.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'Aucune chambre disponible pour ces dates.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final room in rooms) ...[
              _RoomCard(room: room, stay: stay),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.stay});

  final Room room;
  final HotelStay stay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = room.basePrice * stay.nights;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${room.roomType.label} · Chambre ${room.roomNumber}', style: textTheme.titleSmall),
              ),
              Text(formatGnf(room.basePrice), style: textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${room.capacity} personne${room.capacity > 1 ? 's' : ''} · par nuit',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (room.description != null && room.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(room.description!, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Réserver · ${formatGnf(total)}',
            onPressed: () => context.push(
              '/hub/hotels/${room.hotelId}/booking',
              extra: HotelBookingSelection(room: room, stay: stay),
            ),
          ),
        ],
      ),
    );
  }
}
