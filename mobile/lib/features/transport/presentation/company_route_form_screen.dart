import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/company_controller.dart';
import '../data/company_repository.dart';
import '../models/currency.dart';
import '../models/station.dart';

class CompanyRouteFormScreen extends ConsumerStatefulWidget {
  const CompanyRouteFormScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyRouteFormScreen> createState() => _CompanyRouteFormScreenState();
}

class _CompanyRouteFormScreenState extends ConsumerState<CompanyRouteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routeCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();

  Station? _origin;
  Station? _destination;
  Currency? _currency;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _routeCodeController.dispose();
    _nameController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      setState(() => _errorMessage = 'Choisissez une station de départ et d\'arrivée.');
      return;
    }
    if (_origin!.id == _destination!.id) {
      setState(() => _errorMessage = 'La station de départ et d\'arrivée doivent être différentes.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(companyRepositoryProvider).createRoute(
        companyId: widget.companyId,
        routeCode: _routeCodeController.text.trim(),
        name: _nameController.text.trim(),
        originStationId: _origin!.id,
        destinationStationId: _destination!.id,
        distanceKm: double.parse(_distanceController.text.trim()),
        estimatedDurationMinutes: int.parse(_durationController.text.trim()),
        basePrice: double.parse(_priceController.text.trim()),
        currencyId: _currency?.id,
      );
      ref.invalidate(companyRoutesProvider(widget.companyId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _positiveNumber(String? value, String label) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return '$label doit être un nombre positif.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stationsAsync = ref.watch(companyStationsProvider);
    final currenciesAsync = ref.watch(companyCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle route')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
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
                      AppTextField(
                        controller: _nameController,
                        label: 'Nom de la route',
                        hint: 'Conakry - Kankan',
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _routeCodeController,
                        label: 'Code de la route',
                        hint: 'CKY-KAN-01',
                        validator: (value) => AppValidators.required(value, 'Le code'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Station de départ', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      stationsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les stations.'),
                        data: (stations) => DropdownButtonFormField<Station>(
                          initialValue: _origin,
                          isExpanded: true,
                          hint: const Text('Choisir une station'),
                          items: [
                            for (final station in stations)
                              DropdownMenuItem(value: station, child: Text(station.name)),
                          ],
                          onChanged: (value) => setState(() => _origin = value),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Station d\'arrivée', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      stationsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les stations.'),
                        data: (stations) => DropdownButtonFormField<Station>(
                          initialValue: _destination,
                          isExpanded: true,
                          hint: const Text('Choisir une station'),
                          items: [
                            for (final station in stations)
                              DropdownMenuItem(value: station, child: Text(station.name)),
                          ],
                          onChanged: (value) => setState(() => _destination = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distance et tarif', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _distanceController,
                              label: 'Distance (km)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) => _positiveNumber(value, 'La distance'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _durationController,
                              label: 'Durée (min)',
                              keyboardType: TextInputType.number,
                              validator: (value) => _positiveNumber(value, 'La durée'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _priceController,
                        label: 'Prix de base',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => _positiveNumber(value, 'Le prix'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Devise (optionnel)', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      currenciesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les devises.'),
                        data: (currencies) => DropdownButtonFormField<Currency>(
                          initialValue: _currency,
                          isExpanded: true,
                          hint: const Text('Hérite de la devise du pays de la compagnie'),
                          items: [
                            for (final currency in currencies)
                              DropdownMenuItem(value: currency, child: Text('${currency.name} (${currency.code})')),
                          ],
                          onChanged: (value) => setState(() => _currency = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Créer la route', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
