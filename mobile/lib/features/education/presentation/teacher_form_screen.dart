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
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/academic_unit.dart';
import '../models/teacher.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Handles both create (teacherId == null) and edit, same shape as
/// Commerce's ProductFormScreen/AcademicUnitFormScreen.
class TeacherFormScreen extends ConsumerWidget {
  const TeacherFormScreen({super.key, required this.institutionId, this.teacherId});

  final String institutionId;
  final String? teacherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teacherId == null) {
      return _TeacherForm(institutionId: institutionId, existingTeacher: null);
    }

    final teacherAsync = ref.watch(teacherDetailProvider(teacherId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier l\'enseignant')),
      body: SafeArea(
        child: teacherAsync.when(
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
                    onPressed: () => ref.invalidate(teacherDetailProvider(teacherId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (teacher) => _TeacherForm(institutionId: institutionId, existingTeacher: teacher),
        ),
      ),
    );
  }
}

class _TeacherForm extends ConsumerStatefulWidget {
  const _TeacherForm({required this.institutionId, required this.existingTeacher});

  final String institutionId;
  final Teacher? existingTeacher;

  @override
  ConsumerState<_TeacherForm> createState() => _TeacherFormState();
}

class _TeacherFormState extends ConsumerState<_TeacherForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(text: widget.existingTeacher?.firstName);
  late final _lastNameController = TextEditingController(text: widget.existingTeacher?.lastName);
  late final _phoneController = TextEditingController(text: widget.existingTeacher?.phone);
  late final _emailController = TextEditingController(text: widget.existingTeacher?.email);
  late final _subjectController = TextEditingController(text: widget.existingTeacher?.subject);

  late final Set<String> _selectedAcademicUnitIds = {...?widget.existingTeacher?.academicUnitIds};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingTeacher != null;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
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
        await repository.updateTeacher(
          teacherId: widget.existingTeacher!.id,
          institutionId: widget.institutionId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          subject: _subjectController.text.trim(),
          academicUnitIds: _selectedAcademicUnitIds.toList(),
        );
        ref.invalidate(teacherDetailProvider(widget.existingTeacher!.id));
      } else {
        await repository.createTeacher(
          institutionId: widget.institutionId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          subject: _subjectController.text.trim(),
          academicUnitIds: _selectedAcademicUnitIds.toList(),
        );
      }
      ref.invalidate(teachersProvider(widget.institutionId));
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
    final unitsAsync = ref.watch(academicUnitsProvider(widget.institutionId));

    return Scaffold(
      appBar: _isEditing ? null : AppBar(title: const Text('Nouvel enseignant')),
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
                        controller: _firstNameController,
                        label: 'Prénom',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) => AppValidators.required(value, 'Le prénom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _lastNameController,
                        label: 'Nom',
                        prefixIcon: Icons.person_outline_rounded,
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
                        label: 'Email (optionnel)',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return null;
                          return _emailRegex.hasMatch(value.trim()) ? null : 'Entrez un email valide.';
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _subjectController,
                        label: 'Matière principale (optionnel)',
                        prefixIcon: Icons.menu_book_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Classes assignées', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      unitsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les classes.'),
                        data: (units) {
                          if (units.isEmpty) {
                            return Text(
                              'Aucune classe créée. Vous pourrez assigner cet enseignant plus tard.',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            );
                          }
                          return Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final unit in units) _AcademicUnitChip(
                                unit: unit,
                                selected: _selectedAcademicUnitIds.contains(unit.id),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _selectedAcademicUnitIds.add(unit.id);
                                  } else {
                                    _selectedAcademicUnitIds.remove(unit.id);
                                  }
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Ajouter l\'enseignant',
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

class _AcademicUnitChip extends StatelessWidget {
  const _AcademicUnitChip({required this.unit, required this.selected, required this.onSelected});

  final AcademicUnit unit;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(label: Text(unit.name), selected: selected, onSelected: onSelected);
  }
}
