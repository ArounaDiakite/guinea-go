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
import '../models/subject.dart';

/// Handles both create (subjectId == null) and edit, same shape as
/// AcademicUnitFormScreen.
class SubjectFormScreen extends ConsumerWidget {
  const SubjectFormScreen({super.key, required this.institutionId, this.subjectId});

  final String institutionId;
  final String? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjectId == null) {
      return _SubjectForm(institutionId: institutionId, existingSubject: null);
    }

    final subjectAsync = ref.watch(subjectDetailProvider(subjectId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la matière')),
      body: SafeArea(
        child: subjectAsync.when(
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
                    onPressed: () => ref.invalidate(subjectDetailProvider(subjectId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (subject) => _SubjectForm(institutionId: institutionId, existingSubject: subject),
        ),
      ),
    );
  }
}

class _SubjectForm extends ConsumerStatefulWidget {
  const _SubjectForm({required this.institutionId, required this.existingSubject});

  final String institutionId;
  final Subject? existingSubject;

  @override
  ConsumerState<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends ConsumerState<_SubjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existingSubject?.name);

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingSubject != null;

  @override
  void dispose() {
    _nameController.dispose();
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
        await repository.updateSubject(
          subjectId: widget.existingSubject!.id,
          institutionId: widget.institutionId,
          name: _nameController.text.trim(),
        );
        ref.invalidate(subjectDetailProvider(widget.existingSubject!.id));
      } else {
        await repository.createSubject(institutionId: widget.institutionId, name: _nameController.text.trim());
      }
      ref.invalidate(subjectsProvider(widget.institutionId));
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
      appBar: _isEditing ? null : AppBar(title: const Text('Nouvelle matière')),
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
                        label: 'Nom de la matière',
                        prefixIcon: Icons.menu_book_outlined,
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Créer la matière',
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
