import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/institutions_controller.dart';
import '../data/institutions_repository.dart';
import '../models/institution.dart';

/// Creates a public institution and its school_administrator account
/// together (POST /admin/institutions) - active immediately, unlike a
/// self-registered private institution (which lands in the Partenaires
/// tab pending validation instead). There is no GET-all-institutions
/// endpoint yet, so this screen is create-only: no list of what's
/// already been created follows it.
class InstitutionCreateScreen extends ConsumerStatefulWidget {
  const InstitutionCreateScreen({super.key});

  @override
  ConsumerState<InstitutionCreateScreen> createState() => _InstitutionCreateScreenState();
}

class _InstitutionCreateScreenState extends ConsumerState<InstitutionCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminCityController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  Country? _country;
  City? _city;
  PublicInstitutionType _institutionType = PublicInstitutionType.primaryPublic;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  InstitutionWithAccount? _created;

  @override
  void dispose() {
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _adminCityController.dispose();
    _adminPasswordController.dispose();
    _nameController.dispose();
    _addressController.dispose();
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
      _created = null;
    });

    try {
      final created = await ref.read(institutionsRepositoryProvider).createPublicInstitution(
        firstName: _adminFirstNameController.text.trim(),
        lastName: _adminLastNameController.text.trim(),
        email: _adminEmailController.text.trim(),
        phone: _adminPhoneController.text.trim(),
        password: _adminPasswordController.text,
        city: _adminCityController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        countryId: _country!.id,
        cityId: _city!.id,
        institutionType: _institutionType,
      );

      _formKey.currentState!.reset();
      _adminFirstNameController.clear();
      _adminLastNameController.clear();
      _adminEmailController.clear();
      _adminPhoneController.clear();
      _adminCityController.clear();
      _adminPasswordController.clear();
      _nameController.clear();
      _addressController.clear();

      setState(() {
        _created = created;
        _country = null;
        _city = null;
        _institutionType = PublicInstitutionType.primaryPublic;
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countriesAsync = ref.watch(institutionCountriesProvider);
    final citiesAsync = ref.watch(institutionCitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un établissement public')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_created != null) ...[
                    _CreatedBanner(created: _created!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_errorMessage != null) ...[
                    AppErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text('Administrateur de l\'établissement', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _adminFirstNameController,
                                label: 'Prénom',
                                validator: (value) => AppValidators.required(value, 'Le prénom'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: AppTextField(
                                controller: _adminLastNameController,
                                label: 'Nom',
                                validator: (value) => AppValidators.required(value, 'Le nom'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _adminEmailController,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          validator: AppValidators.email,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _adminPhoneController,
                          label: 'Téléphone',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          validator: AppValidators.phone,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _adminCityController,
                          label: 'Ville (de l\'administrateur)',
                          prefixIcon: Icons.location_city_outlined,
                          validator: (value) => AppValidators.required(value, 'La ville'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _adminPasswordController,
                          label: 'Mot de passe',
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          validator: AppValidators.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Établissement', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: 'Nom de l\'établissement',
                          prefixIcon: Icons.school_outlined,
                          validator: (value) => AppValidators.required(value, 'Le nom'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Type d\'établissement', style: textTheme.labelMedium),
                        const SizedBox(height: AppSpacing.xs),
                        DropdownButtonFormField<PublicInstitutionType>(
                          initialValue: _institutionType,
                          isExpanded: true,
                          items: [
                            for (final type in PublicInstitutionType.values)
                              DropdownMenuItem(value: type, child: Text(type.label)),
                          ],
                          onChanged: (value) =>
                              setState(() => _institutionType = value ?? _institutionType),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _addressController,
                          label: 'Adresse',
                          prefixIcon: Icons.location_on_outlined,
                          validator: (value) => AppValidators.required(value, 'L\'adresse'),
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
                              hint: Text(
                                _country == null ? 'Choisissez d\'abord un pays' : 'Choisir une ville',
                              ),
                              items: [
                                for (final city in available)
                                  DropdownMenuItem(value: city, child: Text(city.name)),
                              ],
                              onChanged: _country == null ? null : (value) => setState(() => _city = value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Créer l\'établissement',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatedBanner extends StatelessWidget {
  const _CreatedBanner({required this.created});

  final InstitutionWithAccount created;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: AppColors.secondaryDark, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${created.institution.name} créé avec succès.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Administrateur : ${created.account.email}',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.secondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
