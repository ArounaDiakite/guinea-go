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
import '../models/managed_route.dart';
import '../models/managed_schedule.dart';

class CompanyScheduleFormScreen extends ConsumerStatefulWidget {
  const CompanyScheduleFormScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyScheduleFormScreen> createState() => _CompanyScheduleFormScreenState();
}

class _CompanyScheduleFormScreenState extends ConsumerState<CompanyScheduleFormScreen> {
  ManagedRoute? _route;
  TimeOfDay? _departureTime;
  TimeOfDay? _estimatedArrivalTime;
  final Set<DayOfWeek> _operatingDays = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  String _formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isDeparture}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isDeparture ? _departureTime : _estimatedArrivalTime) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isDeparture) {
        _departureTime = picked;
      } else {
        _estimatedArrivalTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_route == null) {
      setState(() => _errorMessage = 'Choisissez une route.');
      return;
    }
    if (_departureTime == null) {
      setState(() => _errorMessage = 'Choisissez une heure de départ.');
      return;
    }
    if (_operatingDays.isEmpty) {
      setState(() => _errorMessage = 'Choisissez au moins un jour de circulation.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(companyRepositoryProvider).createSchedule(
        companyId: widget.companyId,
        routeId: _route!.id,
        departureTime: _formatTimeOfDay(_departureTime!),
        estimatedArrivalTime: _estimatedArrivalTime != null ? _formatTimeOfDay(_estimatedArrivalTime!) : null,
        operatingDays: _operatingDays.toList(),
      );
      ref.invalidate(companySchedulesProvider(widget.companyId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final routesAsync = ref.watch(companyRoutesProvider(widget.companyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel horaire')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      AppErrorBanner(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text('Route', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    routesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les routes.'),
                      data: (routes) => routes.isEmpty
                          ? Text(
                              'Créez d\'abord une route pour pouvoir lui associer un horaire.',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            )
                          : DropdownButtonFormField<ManagedRoute>(
                              initialValue: _route,
                              isExpanded: true,
                              hint: const Text('Choisir une route'),
                              items: [
                                for (final route in routes)
                                  DropdownMenuItem(value: route, child: Text(route.name)),
                              ],
                              onChanged: (value) => setState(() => _route = value),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Heure de départ', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () => _pickTime(isDeparture: true),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_outlined)),
                        child: Text(_departureTime?.format(context) ?? 'Choisir une heure'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Heure d\'arrivée estimée (optionnel)', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: () => _pickTime(isDeparture: false),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_outlined)),
                        child: Text(_estimatedArrivalTime?.format(context) ?? 'Choisir une heure'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Jours de circulation', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final day in DayOfWeek.values)
                          FilterChip(
                            label: Text(day.shortLabel),
                            selected: _operatingDays.contains(day),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _operatingDays.add(day);
                              } else {
                                _operatingDays.remove(day);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Créer l\'horaire', isLoading: _isSubmitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
