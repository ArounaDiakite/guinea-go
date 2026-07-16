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
import '../application/hotel_search_controller.dart';
import '../models/hotel_search_params.dart';
import '../models/hotel_search_result.dart';
import '../models/hotel_stay.dart';

class HotelResultsScreen extends ConsumerWidget {
  const HotelResultsScreen({super.key, required this.params});

  final HotelSearchParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(hotelSearchResultsProvider(params));
    final textTheme = Theme.of(context).textTheme;
    final nights = params.checkOut.difference(params.checkIn).inDays;

    return Scaffold(
      appBar: AppBar(title: Text('${params.cityName} · $nights nuit${nights > 1 ? 's' : ''}')),
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
                    onPressed: () => ref.invalidate(hotelSearchResultsProvider(params)),
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
                      const Icon(Icons.hotel_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucun hôtel disponible pour ces dates.',
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Essayez une autre ville ou d\'autres dates.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final sorted = [...results]..sort((a, b) => a.startingPrice.compareTo(b.startingPrice));

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: sorted.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _HotelResultCard(
                result: sorted[index],
                stay: HotelStay(checkIn: params.checkIn, checkOut: params.checkOut),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HotelResultCard extends StatelessWidget {
  const _HotelResultCard({required this.result, required this.stay});

  final HotelSearchResult result;
  final HotelStay stay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => context.push('/hub/hotels/${result.hotel.id}', extra: stay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(result.hotel.name, style: textTheme.titleSmall, overflow: TextOverflow.ellipsis),
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
                  '${result.hotel.address}, ${result.cityName}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                  'À partir de ${formatGnf(result.startingPrice)}',
                  style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
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
