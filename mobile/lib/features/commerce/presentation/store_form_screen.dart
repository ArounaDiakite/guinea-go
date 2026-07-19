import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/store_manager_controller.dart';
import '../data/store_manager_repository.dart';

class StoreFormScreen extends ConsumerStatefulWidget {
  const StoreFormScreen({super.key});

  @override
  ConsumerState<StoreFormScreen> createState() => _StoreFormScreenState();
}

class _StoreFormScreenState extends ConsumerState<StoreFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shippingInfoController = TextEditingController();

  Country? _country;
  City? _city;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _shippingInfoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_country == null || _city == null) {
      setState(() => _errorMessage = 'Choisissez un pays et une ville.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(storeManagerRepositoryProvider).createStore(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        countryId: _country!.id,
        cityId: _city!.id,
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        shippingInfo: _shippingInfoController.text.trim(),
      );
      ref.invalidate(myStoresProvider);
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
    final countriesAsync = ref.watch(storeManagerCountriesProvider);
    final citiesAsync = ref.watch(storeManagerCitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle boutique')),
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
                        label: 'Nom de la boutique',
                        prefixIcon: Icons.storefront_outlined,
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Téléphone',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) => AppValidators.required(value, 'Le téléphone'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => AppValidators.required(value, 'L\'email'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Pays', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      countriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les pays.'),
                        data: (countries) => DropdownButtonFormField<Country>(
                          initialValue: _country,
                          isExpanded: true,
                          hint: const Text('Choisir un pays'),
                          items: [
                            for (final country in countries)
                              DropdownMenuItem(value: country, child: Text(country.name)),
                          ],
                          onChanged: (value) => setState(() {
                            _country = value;
                            _city = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Ville', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      citiesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les villes.'),
                        data: (cities) {
                          final available = _country == null
                              ? const <City>[]
                              : cities.where((city) => city.countryCode == _country!.code).toList();
                          return DropdownButtonFormField<City>(
                            initialValue: _city,
                            isExpanded: true,
                            hint: Text(_country == null ? 'Choisissez d\'abord un pays' : 'Choisir une ville'),
                            items: [
                              for (final city in available) DropdownMenuItem(value: city, child: Text(city.name)),
                            ],
                            onChanged: _country == null ? null : (value) => setState(() => _city = value),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _addressController,
                        label: 'Adresse',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (value) => AppValidators.required(value, 'L\'adresse'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _shippingInfoController,
                        label: 'Informations de livraison (optionnel)',
                        prefixIcon: Icons.local_shipping_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnel)',
                        prefixIcon: Icons.notes_outlined,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Créer la boutique', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
