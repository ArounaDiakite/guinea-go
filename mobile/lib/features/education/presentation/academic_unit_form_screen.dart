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
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/academic_unit.dart';

/// Handles both create (academicUnitId == null) and edit - edit mode
/// watches academicUnitDetailProvider to pre-fill the form once the
/// unit's current data has loaded, same shape as Commerce's
/// ProductFormScreen.
class AcademicUnitFormScreen extends ConsumerWidget {
  const AcademicUnitFormScreen({super.key, required this.institutionId, this.academicUnitId});

  final String institutionId;
  final String? academicUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (academicUnitId == null) {
      return _AcademicUnitForm(institutionId: institutionId, existingUnit: null);
    }

    final unitAsync = ref.watch(academicUnitDetailProvider(academicUnitId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la classe')),
      body: SafeArea(
        child: unitAsync.when(
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
                    onPressed: () => ref.invalidate(academicUnitDetailProvider(academicUnitId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (unit) => _AcademicUnitForm(institutionId: institutionId, existingUnit: unit),
        ),
      ),
    );
  }
}

class _AcademicUnitForm extends ConsumerStatefulWidget {
  const _AcademicUnitForm({required this.institutionId, required this.existingUnit});

  final String institutionId;
  final AcademicUnit? existingUnit;

  @override
  ConsumerState<_AcademicUnitForm> createState() => _AcademicUnitFormState();
}

class _AcademicUnitFormState extends ConsumerState<_AcademicUnitForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existingUnit?.name);
  late final _levelController = TextEditingController(text: widget.existingUnit?.level);

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingUnit != null;

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(schoolRepositoryProvider);

      if (_isEditing) {
        await repository.updateAcademicUnit(
          academicUnitId: widget.existingUnit!.id,
          institutionId: widget.institutionId,
          name: _nameController.text.trim(),
          level: _levelController.text.trim(),
        );
        ref.invalidate(academicUnitDetailProvider(widget.existingUnit!.id));
      } else {
        await repository.createAcademicUnit(
          institutionId: widget.institutionId,
          name: _nameController.text.trim(),
          level: _levelController.text.trim(),
        );
      }
      ref.invalidate(academicUnitsProvider(widget.institutionId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isEditing ? null : AppBar(title: const Text('Nouvelle classe / département')),
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
                        label: 'Nom (ex: CM2 A, Terminale S2, Génie Civil)',
                        prefixIcon: Icons.class_outlined,
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _levelController,
                        label: 'Niveau (ex: CE1, Seconde, L1)',
                        prefixIcon: Icons.stairs_outlined,
                        validator: (value) => AppValidators.required(value, 'Le niveau'),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Créer',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
