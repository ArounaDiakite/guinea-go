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
import '../application/event_search_controller.dart';
import '../models/event.dart';
import '../models/event_search_params.dart';
import '../models/event_search_result.dart';

class EventResultsScreen extends ConsumerWidget {
  const EventResultsScreen({super.key, required this.params});

  final EventSearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(eventSearchResultsProvider(params));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(params.cityName ?? 'Résultats')),
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
                    onPressed: () => ref.invalidate(eventSearchResultsProvider(params)),
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
                      const Icon(Icons.confirmation_number_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun événement trouvé.',
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Essayez d\'autres filtres.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final sorted = [...results]..sort((a, b) => a.event.startDatetime.compareTo(b.event.startDatetime));

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _EventResultCard(result: sorted[index]),
            );
          },
        ),
      ),
    );
  }
}

const _months = [
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

String _formatDateTime(DateTime dateTime) {
  final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  return '${dateTime.day} ${_months[dateTime.month - 1]} · $time';
}

class _EventResultCard extends StatelessWidget {
  const _EventResultCard({required this.result});

  final EventSearchResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final soldOut = result.startingPrice == null;

    return AppCard(
      onTap: () => context.push('/hub/events/${result.event.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(result.event.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              ),
              if (result.averageRating != null) ...[
                const Icon(Icons.star_rounded, color: AppColors.accentDark, size: 18),
                const SizedBox(width: 2),
                Text(
                  result.averageRating!.toStringAsFixed(1),
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.accentDark),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${result.event.venue}, ${result.cityName}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _formatDateTime(result.event.startDatetime),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  result.event.category.label,
                  style: textTheme.labelSmall?.copyWith(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (result.reviewCount > 0)
                Flexible(
                  child: Text(
                    '${result.reviewCount} avis',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              else
                const Spacer(),
              Flexible(
                flex: 2,
                child: Text(
                  soldOut ? 'Complet' : 'À partir de ${formatGnf(result.startingPrice!)}',
                  style: textTheme.titleMedium?.copyWith(color: soldOut ? AppColors.error : AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
