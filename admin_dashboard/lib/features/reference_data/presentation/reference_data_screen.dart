import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/reference_data_controller.dart';
import '../data/reference_data_repository.dart';
import '../models/reference_data.dart';

/// Basic CRUD-minus-the-D management for shared reference data
/// (countries/cities/currencies - CLAUDE.md's "Données de référence"
/// section): readable by anyone already, writable only from here. A
/// currency has to exist before a country can reference it by code,
/// and a country before a city can - the tab order below matches that
/// dependency chain.
class ReferenceDataScreen extends StatelessWidget {
  const ReferenceDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Données de référence'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Devises'),
              Tab(text: 'Pays'),
              Tab(text: 'Villes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CurrencyTab(), _CountryTab(), _CityTab()],
        ),
      ),
    );
  }
}

class _CurrencyTab extends ConsumerWidget {
  const _CurrencyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(currenciesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddCurrencyDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une devise'),
      ),
      body: currenciesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          message: extractApiErrorMessage(error),
          onRetry: () => ref.invalidate(currenciesProvider),
        ),
        data: (currencies) {
          if (currencies.isEmpty) {
            return const _EmptyState(message: 'Aucune devise enregistrée pour le moment.');
          }
          return _CenteredList(
            children: [
              for (final currency in currencies)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${currency.name} (${currency.code})', style: textTheme.titleSmall),
                            Text(
                              'Symbole ${currency.symbol}',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(isActive: currency.isActive),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CountryTab extends ConsumerWidget {
  const _CountryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countriesAsync = ref.watch(referenceCountriesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddCountryDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un pays'),
      ),
      body: countriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          message: extractApiErrorMessage(error),
          onRetry: () => ref.invalidate(referenceCountriesProvider),
        ),
        data: (countries) {
          if (countries.isEmpty) {
            return const _EmptyState(message: 'Aucun pays enregistré pour le moment.');
          }
          return _CenteredList(
            children: [
              for (final country in countries)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${country.name} (${country.code})', style: textTheme.titleSmall),
                            Text(
                              '${country.timezone} · ${country.languages.join(', ')}',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(isActive: country.isActive),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CityTab extends ConsumerWidget {
  const _CityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(referenceCitiesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddCityDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une ville'),
      ),
      body: citiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          message: extractApiErrorMessage(error),
          onRetry: () => ref.invalidate(referenceCitiesProvider),
        ),
        data: (cities) {
          if (cities.isEmpty) {
            return const _EmptyState(message: 'Aucune ville enregistrée pour le moment.');
          }
          return _CenteredList(
            children: [
              for (final city in cities)
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(city.name, style: textTheme.titleSmall),
                            Text(
                              '${city.stateOrRegion} · ${city.countryCode}',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(isActive: city.isActive),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CenteredList extends StatelessWidget {
  const _CenteredList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: children.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => children[index],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.textHint, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppErrorBanner(message: message),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Réessayer', variant: AppButtonVariant.secondary, expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AddCurrencyDialog extends ConsumerStatefulWidget {
  const _AddCurrencyDialog();

  @override
  ConsumerState<_AddCurrencyDialog> createState() => _AddCurrencyDialogState();
}

class _AddCurrencyDialogState extends ConsumerState<_AddCurrencyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(referenceDataRepositoryProvider).createCurrency(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim(),
      );
      ref.invalidate(currenciesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle devise'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                AppErrorBanner(message: _errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                controller: _codeController,
                label: 'Code (ex. GNF)',
                validator: (value) => AppValidators.required(value, 'Le code'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameController,
                label: 'Nom',
                validator: (value) => AppValidators.required(value, 'Le nom'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _symbolController,
                label: 'Symbole',
                validator: (value) => AppValidators.required(value, 'Le symbole'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        AppButton(label: 'Créer', expand: false, isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}

class _AddCountryDialog extends ConsumerStatefulWidget {
  const _AddCountryDialog();

  @override
  ConsumerState<_AddCountryDialog> createState() => _AddCountryDialogState();
}

class _AddCountryDialogState extends ConsumerState<_AddCountryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _languagesController = TextEditingController(text: 'fr');
  final _paymentMethodsController = TextEditingController();

  CurrencyRecord? _currency;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _timezoneController.dispose();
    _languagesController.dispose();
    _paymentMethodsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currency == null) {
      setState(() => _errorMessage = 'Choisissez une devise.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(referenceDataRepositoryProvider).createCountry(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        currencyCode: _currency!.code,
        timezone: _timezoneController.text.trim(),
        languages: _splitList(_languagesController.text),
        paymentMethods: _splitList(_paymentMethodsController.text),
      );
      ref.invalidate(referenceCountriesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(currenciesProvider);

    return AlertDialog(
      title: const Text('Nouveau pays'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  AppErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  controller: _codeController,
                  label: 'Code ISO (ex. GN)',
                  validator: (value) => AppValidators.required(value, 'Le code'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'Nom',
                  validator: (value) => AppValidators.required(value, 'Le nom'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Devise', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                currenciesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) =>
                      const AppErrorBanner(message: 'Impossible de charger les devises.'),
                  data: (currencies) => DropdownButtonFormField<CurrencyRecord>(
                    initialValue: _currency,
                    isExpanded: true,
                    hint: const Text('Choisir une devise'),
                    items: [
                      for (final currency in currencies)
                        DropdownMenuItem(value: currency, child: Text('${currency.name} (${currency.code})')),
                    ],
                    onChanged: (value) => setState(() => _currency = value),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _timezoneController,
                  label: 'Fuseau horaire (ex. Africa/Conakry)',
                  validator: (value) => AppValidators.required(value, 'Le fuseau horaire'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _languagesController,
                  label: 'Langues (séparées par des virgules)',
                  validator: (value) => AppValidators.required(value, 'Au moins une langue'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _paymentMethodsController,
                  label: 'Moyens de paiement (séparés par des virgules)',
                  hint: 'orange_money, cash',
                  validator: (value) => AppValidators.required(value, 'Au moins un moyen de paiement'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        AppButton(label: 'Créer', expand: false, isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}

class _AddCityDialog extends ConsumerStatefulWidget {
  const _AddCityDialog();

  @override
  ConsumerState<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends ConsumerState<_AddCityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stateOrRegionController = TextEditingController();

  CountryRecord? _country;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _stateOrRegionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_country == null) {
      setState(() => _errorMessage = 'Choisissez un pays.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(referenceDataRepositoryProvider).createCity(
        countryCode: _country!.code,
        name: _nameController.text.trim(),
        stateOrRegion: _stateOrRegionController.text.trim(),
      );
      ref.invalidate(referenceCitiesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(referenceCountriesProvider);

    return AlertDialog(
      title: const Text('Nouvelle ville'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  AppErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text('Pays', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                countriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) =>
                      const AppErrorBanner(message: 'Impossible de charger les pays.'),
                  data: (countries) => DropdownButtonFormField<CountryRecord>(
                    initialValue: _country,
                    isExpanded: true,
                    hint: const Text('Choisir un pays'),
                    items: [
                      for (final country in countries)
                        DropdownMenuItem(value: country, child: Text(country.name)),
                    ],
                    onChanged: (value) => setState(() => _country = value),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'Nom de la ville',
                  validator: (value) => AppValidators.required(value, 'Le nom'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _stateOrRegionController,
                  label: 'Région',
                  validator: (value) => AppValidators.required(value, 'La région'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        AppButton(label: 'Créer', expand: false, isLoading: _isSubmitting, onPressed: _submit),
      ],
    );
  }
}

List<String> _splitList(String raw) =>
    raw.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
