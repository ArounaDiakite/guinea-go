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
import '../data/company_repository.dart';
import '../models/managed_bus.dart';

class CompanyBusesScreen extends ConsumerWidget {
  const CompanyBusesScreen({super.key, required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busesAsync = ref.watch(companyBusesProvider(companyId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/company/buses/new', extra: companyId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: busesAsync.when(
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
                    onPressed: () => ref.invalidate(companyBusesProvider(companyId)),
                  ),
                ],
              ),
            ),
          ),
          data: (buses) {
            if (buses.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_bus_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun bus enregistré pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: buses.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _BusCard(bus: buses[index]),
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
  BusStatus.available: _StatusStyle('Disponible', AppColors.secondaryDark, AppColors.secondaryLight),
  BusStatus.inService: _StatusStyle('En service', AppColors.info, AppColors.infoLight),
  BusStatus.maintenance: _StatusStyle('En maintenance', AppColors.accentDark, AppColors.accentLight),
  BusStatus.outOfService: _StatusStyle('Hors service', AppColors.error, AppColors.errorLight),
  BusStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _BusCard extends ConsumerStatefulWidget {
  const _BusCard({required this.bus});

  final ManagedBus bus;

  @override
  ConsumerState<_BusCard> createState() => _BusCardState();
}

class _BusCardState extends ConsumerState<_BusCard> {
  bool _isGeneratingSeats = false;

  Future<void> _generateSeats() async {
    setState(() => _isGeneratingSeats = true);
    try {
      await ref.read(companyRepositoryProvider).generateSeatsForBus(widget.bus.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sièges générés.')));
      }
    } catch (error) {
      if (mounted) {
        // A 400 here almost always means the seats already exist (the
        // endpoint is one-shot) - read either way as "nothing left to
        // do" rather than a hard failure the owner needs to act on.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSeats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bus = widget.bus;
    final style = _statusStyles[bus.status]!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${bus.brand} ${bus.model}', style: textTheme.titleSmall),
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
          Text(
            'Immatriculation ${bus.registrationNumber} · Flotte n°${bus.fleetNumber}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.event_seat_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${bus.seatCapacity} places · ${bus.busType.label}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Générer les sièges',
            variant: AppButtonVariant.secondary,
            isLoading: _isGeneratingSeats,
            onPressed: _generateSeats,
          ),
        ],
      ),
    );
  }
}
