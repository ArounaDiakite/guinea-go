import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/institution.dart';

class InstitutionHomeScreen extends ConsumerWidget {
  const InstitutionHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionAsync = ref.watch(myInstitutionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon établissement')),
      body: SafeArea(
        child: institutionAsync.when(
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
                    onPressed: () => ref.invalidate(myInstitutionProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (institution) =>
              institution == null ? const _CreateInstitutionForm() : _InstitutionMenu(institution: institution),
        ),
      ),
    );
  }
}

class _InstitutionMenu extends StatelessWidget {
  const _InstitutionMenu({required this.institution});

  final Institution institution;

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
                child: const Icon(Icons.school_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution.name,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      institution.institutionType.label,
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Gestion', style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.class_outlined,
          label: 'Classes / départements',
          subtitle: 'Unités académiques de l\'établissement',
          onTap: () => context.push('/hub/school/academic-units', extra: institution.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.badge_outlined,
          label: 'Enseignants',
          subtitle: 'Personnel enseignant',
          onTap: () => context.push('/hub/school/teachers', extra: institution.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.groups_outlined,
          label: 'Élèves',
          subtitle: 'Inscriptions par classe',
          onTap: () => context.push('/hub/school/students', extra: institution.id),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ManagementTile(
          icon: Icons.menu_book_outlined,
          label: 'Matières',
          subtitle: 'Matières enseignées dans l\'établissement',
          onTap: () => context.push('/hub/school/subjects', extra: institution.id),
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
                Text(label, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _CreateInstitutionForm extends ConsumerStatefulWidget {
  const _CreateInstitutionForm();

  @override
  ConsumerState<_CreateInstitutionForm> createState() => _CreateInstitutionFormState();
}

class _CreateInstitutionFormState extends ConsumerState<_CreateInstitutionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  Country? _country;
  City? _city;
  InstitutionType _institutionType = privateInstitutionTypes.first;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
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
    });

    try {
      await ref.read(schoolRepositoryProvider).createInstitution(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        countryId: _country!.id,
        cityId: _city!.id,
        institutionType: _institutionType,
      );
      ref.invalidate(myInstitutionProvider);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countriesAsync = ref.watch(schoolCountriesProvider);
    final citiesAsync = ref.watch(schoolCitiesProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Créez votre établissement', style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Renseignez les informations de votre établissement pour commencer à gérer classes, '
          'enseignants et élèves.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.accentDark, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ce formulaire ne couvre que les établissements privés. Un établissement public '
                  'est créé uniquement par un administrateur système.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.accentDark),
                ),
              ),
            ],
          ),
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
                  label: 'Nom de l\'établissement',
                  prefixIcon: Icons.school_outlined,
                  validator: (value) => AppValidators.required(value, 'Le nom'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Type d\'établissement', style: textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<InstitutionType>(
                  initialValue: _institutionType,
                  isExpanded: true,
                  items: [
                    for (final type in privateInstitutionTypes)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) => setState(() => _institutionType = value ?? _institutionType),
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
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Créer mon établissement',
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
