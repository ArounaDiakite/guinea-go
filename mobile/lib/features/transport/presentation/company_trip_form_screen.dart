import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/company_controller.dart';
import '../data/company_repository.dart';
import '../models/managed_bus.dart';
import '../models/managed_driver.dart';
import '../models/managed_route.dart';
import '../models/managed_schedule.dart';

class CompanyTripFormScreen extends ConsumerStatefulWidget {
  const CompanyTripFormScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyTripFormScreen> createState() => _CompanyTripFormScreenState();
}

class _CompanyTripFormScreenState extends ConsumerState<CompanyTripFormScreen> {
  ManagedRoute? _route;
  ManagedSchedule? _schedule;
  ManagedBus? _bus;
  ManagedDriver? _driver;
  DateTime _travelDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _travelDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_route == null || _schedule == null || _bus == null || _driver == null) {
      setState(() => _errorMessage = 'Choisissez une route, un horaire, un bus et un chauffeur.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(companyRepositoryProvider).createTrip(
        companyId: widget.companyId,
        routeId: _route!.id,
        scheduleId: _schedule!.id,
        busId: _bus!.id,
        driverId: _driver!.id,
        travelDate: _travelDate,
      );
      ref.invalidate(companyTripsProvider(widget.companyId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final routesAsync = ref.watch(companyRoutesProvider(widget.companyId));
    final schedulesAsync = ref.watch(companySchedulesProvider(widget.companyId));
    final busesAsync = ref.watch(companyBusesProvider(widget.companyId));
    final driversAsync = ref.watch(companyDriversProvider(widget.companyId));

    final schedulesForRoute = (schedulesAsync.value ?? const <ManagedSchedule>[])
        .where((schedule) => _route == null || schedule.routeId == _route!.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau trajet')),
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
                      data: (routes) => DropdownButtonFormField<ManagedRoute>(
                        initialValue: _route,
                        isExpanded: true,
                        hint: const Text('Choisir une route'),
                        items: [
                          for (final route in routes) DropdownMenuItem(value: route, child: Text(route.name)),
                        ],
                        onChanged: (value) => setState(() {
                          _route = value;
                          _schedule = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Horaire', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    schedulesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les horaires.'),
                      data: (_) => DropdownButtonFormField<ManagedSchedule>(
                        initialValue: _schedule,
                        isExpanded: true,
                        hint: Text(_route == null ? 'Choisissez d\'abord une route' : 'Choisir un horaire'),
                        items: [
                          for (final schedule in schedulesForRoute)
                            DropdownMenuItem(
                              value: schedule,
                              child: Text(schedule.departureTime.substring(0, 5)),
                            ),
                        ],
                        onChanged: _route == null ? null : (value) => setState(() => _schedule = value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Bus', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    busesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les bus.'),
                      data: (buses) => DropdownButtonFormField<ManagedBus>(
                        initialValue: _bus,
                        isExpanded: true,
                        hint: const Text('Choisir un bus'),
                        items: [
                          for (final bus in buses)
                            DropdownMenuItem(value: bus, child: Text('${bus.brand} ${bus.model} (${bus.registrationNumber})')),
                        ],
                        onChanged: (value) => setState(() => _bus = value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Chauffeur', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    driversAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) =>
                          const AppErrorBanner(message: 'Impossible de charger les chauffeurs.'),
                      data: (drivers) => DropdownButtonFormField<ManagedDriver>(
                        initialValue: _driver,
                        isExpanded: true,
                        hint: const Text('Choisir un chauffeur'),
                        items: [
                          for (final driver in drivers)
                            DropdownMenuItem(value: driver, child: Text(driver.fullName)),
                        ],
                        onChanged: (value) => setState(() => _driver = value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Date du voyage', style: textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                        child: Text(_formatDate(_travelDate)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Créer le trajet', isLoading: _isSubmitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
