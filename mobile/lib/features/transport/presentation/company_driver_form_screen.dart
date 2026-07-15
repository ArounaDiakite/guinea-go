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
import '../models/managed_driver.dart';

class CompanyDriverFormScreen extends ConsumerStatefulWidget {
  const CompanyDriverFormScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyDriverFormScreen> createState() => _CompanyDriverFormScreenState();
}

class _CompanyDriverFormScreenState extends ConsumerState<CompanyDriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _employeeNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _yearsExperienceController = TextEditingController(text: '0');

  DriverGender _gender = DriverGender.male;
  LicenseCategory _licenseCategory = LicenseCategory.d;
  DateTime? _dateOfBirth;
  DateTime? _licenseExpiryDate;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _employeeNumberController.dispose();
    _licenseNumberController.dispose();
    _yearsExperienceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isBirthDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isBirthDate ? DateTime(now.year - 30) : now.add(const Duration(days: 365)),
      firstDate: isBirthDate ? DateTime(now.year - 80) : now,
      lastDate: isBirthDate ? DateTime(now.year - 18) : DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() {
      if (isBirthDate) {
        _dateOfBirth = picked;
      } else {
        _licenseExpiryDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null || _licenseExpiryDate == null) {
      setState(() => _errorMessage = 'Renseignez la date de naissance et la date d\'expiration du permis.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(companyRepositoryProvider).createDriverWithAccount(
        companyId: widget.companyId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        city: _cityController.text.trim(),
        employeeNumber: _employeeNumberController.text.trim(),
        gender: _gender,
        dateOfBirth: _dateOfBirth!,
        licenseNumber: _licenseNumberController.text.trim(),
        licenseCategory: _licenseCategory,
        licenseExpiryDate: _licenseExpiryDate!,
        yearsOfExperience: int.tryParse(_yearsExperienceController.text.trim()) ?? 0,
      );
      ref.invalidate(companyDriversProvider(widget.companyId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Choisir une date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau chauffeur')),
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
                      Text('Compte', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              validator: (value) => AppValidators.required(value, 'Le prénom'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _lastNameController,
                              label: 'Nom',
                              validator: (value) => AppValidators.required(value, 'Le nom'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: AppValidators.email,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Téléphone',
                        keyboardType: TextInputType.phone,
                        validator: AppValidators.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _cityController,
                        label: 'Ville',
                        validator: (value) => AppValidators.required(value, 'La ville'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Mot de passe',
                        obscureText: _obscurePassword,
                        validator: AppValidators.password,
                        textInputAction: TextInputAction.next,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                      Text('Profil chauffeur', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _employeeNumberController,
                        label: 'Matricule employé',
                        validator: (value) => AppValidators.required(value, 'Le matricule'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Genre', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<DriverGender>(
                        initialValue: _gender,
                        isExpanded: true,
                        items: [
                          for (final gender in DriverGender.values)
                            DropdownMenuItem(value: gender, child: Text(gender.label)),
                        ],
                        onChanged: (value) => setState(() => _gender = value ?? _gender),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Date de naissance', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: () => _pickDate(isBirthDate: true),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                          child: Text(_formatDate(_dateOfBirth)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _licenseNumberController,
                        label: 'Numéro de permis',
                        validator: (value) => AppValidators.required(value, 'Le numéro de permis'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Catégorie de permis', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<LicenseCategory>(
                        initialValue: _licenseCategory,
                        isExpanded: true,
                        items: [
                          for (final category in LicenseCategory.values)
                            DropdownMenuItem(value: category, child: Text(category.apiValue)),
                        ],
                        onChanged: (value) => setState(() => _licenseCategory = value ?? _licenseCategory),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Expiration du permis', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: () => _pickDate(isBirthDate: false),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.event_outlined)),
                          child: Text(_formatDate(_licenseExpiryDate)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _yearsExperienceController,
                        label: 'Années d\'expérience',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Ajouter le chauffeur', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
