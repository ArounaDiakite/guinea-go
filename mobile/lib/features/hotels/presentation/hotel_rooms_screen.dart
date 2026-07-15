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
import '../application/hotel_owner_controller.dart';
import '../data/hotel_owner_repository.dart';
import '../models/room.dart';

class HotelRoomsScreen extends ConsumerWidget {
  const HotelRoomsScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(hotelRoomsManagedProvider(hotelId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chambres')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/hotel/rooms/new', extra: hotelId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: roomsAsync.when(
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
                    onPressed: () => ref.invalidate(hotelRoomsManagedProvider(hotelId)),
                  ),
                ],
              ),
            ),
          ),
          data: (rooms) {
            if (rooms.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune chambre enregistrée pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: rooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _RoomCard(room: rooms[index], hotelId: hotelId),
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
  RoomStatus.available: _StatusStyle('Disponible', AppColors.secondaryDark, AppColors.secondaryLight),
  RoomStatus.maintenance: _StatusStyle('En maintenance', AppColors.accentDark, AppColors.accentLight),
};

class _RoomCard extends ConsumerStatefulWidget {
  const _RoomCard({required this.room, required this.hotelId});

  final Room room;
  final String hotelId;

  @override
  ConsumerState<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends ConsumerState<_RoomCard> {
  bool _isToggling = false;

  Future<void> _toggleStatus() async {
    setState(() => _isToggling = true);
    final nextStatus = widget.room.status == RoomStatus.available ? RoomStatus.maintenance : RoomStatus.available;

    try {
      await ref.read(hotelOwnerRepositoryProvider).updateRoomStatus(widget.room, nextStatus);
      ref.invalidate(hotelRoomsManagedProvider(widget.hotelId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final room = widget.room;
    final style = _statusStyles[room.status]!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${room.roomType.label} · Chambre ${room.roomNumber}', style: textTheme.titleSmall),
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${room.capacity} personne${room.capacity > 1 ? 's' : ''}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text('${formatGnf(room.basePrice)} / nuit', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: room.status == RoomStatus.available ? 'Mettre en maintenance' : 'Remettre disponible',
            variant: AppButtonVariant.secondary,
            isLoading: _isToggling,
            onPressed: _toggleStatus,
          ),
        ],
      ),
    );
  }
}
