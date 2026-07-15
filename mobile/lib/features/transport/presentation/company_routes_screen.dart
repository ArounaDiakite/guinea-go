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
import '../models/station.dart';
import '../../../core/utils/currency.dart';

class CompanyRoutesScreen extends ConsumerWidget {
  const CompanyRoutesScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(companyRoutesProvider(companyId));
    final stationsAsync = ref.watch(companyStationsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Routes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/company/routes/new', extra: companyId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: routesAsync.when(
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
                    onPressed: () => ref.invalidate(companyRoutesProvider(companyId)),
                  ),
                ],
              ),
            ),
          ),
          data: (routes) {
            if (routes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alt_route_rounded, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune route créée pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            final stationNames = <String, String>{
              for (final station in stationsAsync.value ?? const <Station>[]) station.id: station.name,
            };

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: routes.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _RouteCard(route: routes[index], stationNames: stationNames),
            );
          },
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.stationNames});

  final ManagedRoute route;
  final Map<String, String> stationNames;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final origin = stationNames[route.originStationId] ?? route.originStationId;
    final destination = stationNames[route.destinationStationId] ?? route.destinationStationId;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(route.name, style: textTheme.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(route.routeCode, style: textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$origin → $destination', style: textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${route.distanceKm.toStringAsFixed(0)} km · ${route.estimatedDurationMinutes} min',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(formatGnf(route.basePrice), style: textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}
