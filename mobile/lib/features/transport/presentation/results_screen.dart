import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/network/api_error.dart';
import '../application/trip_search_controller.dart';
import '../models/trip.dart';
import '../models/trip_search_params.dart';
import '../utils/currency.dart';

enum _SortOrder { departureTime, price }

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.params});

  final TripSearchParams params;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _SortOrder _sortOrder = _SortOrder.departureTime;

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(tripSearchResultsProvider(widget.params));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.params.originCityName} → ${widget.params.destinationCityName}'),
      ),
      body: SafeArea(
        child: resultsAsync.when(
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
                    onPressed: () => ref.invalidate(tripSearchResultsProvider(widget.params)),
                  ),
                ],
              ),
            ),
          ),
          data: (results) {
            if (results.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_bus_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun trajet disponible pour cette date.',
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Essayez une autre date ou d\'autres villes.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final sorted = [...results];
            switch (_sortOrder) {
              case _SortOrder.departureTime:
                sorted.sort((a, b) => a.trip.departureDatetime.compareTo(b.trip.departureDatetime));
              case _SortOrder.price:
                sorted.sort((a, b) => a.trip.price.compareTo(b.trip.price));
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Row(
                    children: [
                      Text('${sorted.length} trajet${sorted.length > 1 ? 's' : ''}', style: textTheme.bodyMedium),
                      const Spacer(),
                      _SortChip(
                        label: 'Horaire',
                        selected: _sortOrder == _SortOrder.departureTime,
                        onTap: () => setState(() => _sortOrder = _SortOrder.departureTime),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _SortChip(
                        label: 'Prix',
                        selected: _sortOrder == _SortOrder.price,
                        onTap: () => setState(() => _sortOrder = _SortOrder.price),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _TripResultCard(result: sorted[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _TripResultCard extends StatelessWidget {
  const _TripResultCard({required this.result});

  final TripSearchResult result;

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trip = result.trip;
    final soldOut = trip.availableSeats <= 0;

    return AppCard(
      onTap: soldOut ? null : () => context.push('/hub/transport/trips/${trip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.company.name,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatGnf(trip.price), style: textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(_formatTime(trip.departureDatetime), style: textTheme.headlineMedium),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Icon(Icons.arrow_right_alt_rounded, color: AppColors.textHint),
              ),
              if (trip.estimatedArrivalDatetime != null)
                Text(_formatTime(trip.estimatedArrivalDatetime!), style: textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                soldOut ? Icons.event_busy_rounded : Icons.event_seat_outlined,
                size: 16,
                color: soldOut ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                soldOut ? 'Complet' : '${trip.availableSeats} places disponibles',
                style: textTheme.bodySmall?.copyWith(color: soldOut ? AppColors.error : AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
