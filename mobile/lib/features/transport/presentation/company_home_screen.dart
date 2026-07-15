import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/company_controller.dart';
import '../data/company_repository.dart';
import '../models/city.dart';
import '../models/country.dart';
import '../models/managed_company.dart';

class CompanyHomeScreen extends ConsumerWidget {
  const CompanyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(myCompanyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ma compagnie')),
      body: SafeArea(
        child: companyAsync.when(
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
                    onPressed: () => ref.invalidate(myCompanyProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (company) =>
              company == null ? const _CreateCompanyForm() : _CompanyMenu(company: company),
        ),
      ),
    );
  }
}

class _CompanyMenu extends StatelessWidget {
  const _CompanyMenu({required this.company});

  final ManagedCompany company;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.apartment_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      company.isVerified ? 'Compagnie vérifiée' : 'Vérification en attente',
                      style: textTheme.bodySmall?.copyWith(
                        color: company.isVerified ? AppColors.secondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Gestion de la flotte', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.directions_bus_outlined,
          label: 'Bus',
          subtitle: 'Flotte, capacité, équipements',
          onTap: () => context.push('/hub/company/buses', extra: company.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.badge_outlined,
          label: 'Chauffeurs',
          subtitle: 'Comptes et profils',
          onTap: () => context.push('/hub/company/drivers', extra: company.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.alt_route_rounded,
          label: 'Routes',
          subtitle: 'Trajets entre stations, tarifs',
          onTap: () => context.push('/hub/company/routes', extra: company.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.event_repeat_rounded,
          label: 'Horaires & trajets',
          subtitle: 'Créneaux récurrents et départs',
          onTap: () => context.push('/hub/company/trips', extra: company.id),
        ),
      ],
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyLarge),
                Text(subtitle, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _CreateCompanyForm extends ConsumerStatefulWidget {
  const _CreateCompanyForm();

  @override
  ConsumerState<_CreateCompanyForm> createState() => _CreateCompanyFormState();
}

class _CreateCompanyFormState extends ConsumerState<_CreateCompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();

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
    _websiteController.dispose();
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
      await ref.read(companyRepositoryProvider).createCompany(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        countryId: _country!.id,
        cityId: _city!.id,
        description: _descriptionController.text.trim(),
        website: _websiteController.text.trim(),
      );
      ref.invalidate(myCompanyProvider);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countriesAsync = ref.watch(companyCountriesProvider);
    final citiesAsync = ref.watch(companyCitiesProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Créez votre compagnie', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Renseignez les informations de votre compagnie de transport pour commencer à gérer bus, chauffeurs et trajets.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  AppErrorBanner(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  controller: _nameController,
                  label: 'Nom de la compagnie',
                  prefixIcon: Icons.apartment_outlined,
                  validator: (value) => AppValidators.required(value, 'Le nom'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  label: 'Téléphone',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: AppValidators.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _emailController,
                  label: 'Email professionnel',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.email,
                  textInputAction: TextInputAction.next,
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
                Text('Pays', style: textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                countriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => const AppErrorBanner(message: 'Impossible de charger les pays.'),
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
                  error: (error, stackTrace) => const AppErrorBanner(message: 'Impossible de charger les villes.'),
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
                  controller: _websiteController,
                  label: 'Site web (optionnel)',
                  prefixIcon: Icons.public_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description (optionnel)',
                  prefixIcon: Icons.notes_outlined,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Créer ma compagnie',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
