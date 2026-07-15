import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/company_controller.dart';
import '../models/managed_route.dart';
import '../models/managed_schedule.dart';
import '../models/trip.dart';
import '../utils/currency.dart';

class CompanyTripsScreen extends ConsumerStatefulWidget {
  const CompanyTripsScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyTripsScreen> createState() => _CompanyTripsScreenState();
}

class _CompanyTripsScreenState extends ConsumerState<CompanyTripsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSchedulesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horaires & trajets'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Horaires'), Tab(text: 'Trajets')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          isSchedulesTab ? '/hub/company/trips/new-schedule' : '/hub/company/trips/new-trip',
          extra: widget.companyId,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(isSchedulesTab ? 'Nouvel horaire' : 'Nouveau trajet'),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _SchedulesTab(companyId: widget.companyId),
            _TripsTab(companyId: widget.companyId),
          ],
        ),
      ),
    );
  }
}

class _SchedulesTab extends ConsumerWidget {
  const _SchedulesTab({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(companySchedulesProvider(companyId));
    final routesAsync = ref.watch(companyRoutesProvider(companyId));
    final textTheme = Theme.of(context).textTheme;

    return schedulesAsync.when(
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
                onPressed: () => ref.invalidate(companySchedulesProvider(companyId)),
              ),
            ],
          ),
        ),
      ),
      data: (schedules) {
        if (schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_repeat_rounded, color: AppColors.textHint, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aucun horaire créé pour le moment.', style: textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        final routeNames = <String, String>{
          for (final route in routesAsync.value ?? const <ManagedRoute>[]) route.id: route.name,
        };

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          itemCount: schedules.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final schedule = schedules[index];
            return _ScheduleCard(schedule: schedule, routeName: routeNames[schedule.routeId] ?? schedule.routeId);
          },
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.routeName});

  final ManagedSchedule schedule;
  final String routeName;

  String _formatTime(String hhmmss) => hhmmss.substring(0, 5);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(routeName, style: textTheme.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: schedule.status == ScheduleStatus.active
                      ? AppColors.secondaryLight
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  schedule.status.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: schedule.status == ScheduleStatus.active
                        ? AppColors.secondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Départ ${_formatTime(schedule.departureTime)}'
                '${schedule.estimatedArrivalTime != null ? ' · Arrivée ${_formatTime(schedule.estimatedArrivalTime!)}' : ''}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final day in schedule.operatingDays)
                Chip(label: Text(day.shortLabel), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripsTab extends ConsumerWidget {
  const _TripsTab({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(companyTripsProvider(companyId));
    final routesAsync = ref.watch(companyRoutesProvider(companyId));
    final textTheme = Theme.of(context).textTheme;

    return tripsAsync.when(
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
                onPressed: () => ref.invalidate(companyTripsProvider(companyId)),
              ),
            ],
          ),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_bus_outlined, color: AppColors.textHint, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aucun trajet créé pour le moment.', style: textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        final sorted = [...trips]..sort((a, b) => b.departureDatetime.compareTo(a.departureDatetime));
        final routeNames = <String, String>{
          for (final route in routesAsync.value ?? const <ManagedRoute>[]) route.id: route.name,
        };

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          itemCount: sorted.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final trip = sorted[index];
            return _TripCard(trip: trip, routeName: routeNames[trip.routeId] ?? trip.routeId);
          },
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.routeName});

  final Trip trip;
  final String routeName;

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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(routeName, style: textTheme.titleSmall)),
              Text(formatGnf(trip.price), style: textTheme.titleSmall?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatDateTime(trip.departureDatetime),
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${trip.bookedSeats} réservé${trip.bookedSeats > 1 ? 's' : ''} / ${trip.availableSeats} disponible${trip.availableSeats > 1 ? 's' : ''}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
