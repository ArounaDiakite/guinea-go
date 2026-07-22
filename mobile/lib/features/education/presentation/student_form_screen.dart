import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/student.dart';

/// Handles both create (studentId == null) and edit, same shape as
/// TeacherFormScreen/AcademicUnitFormScreen.
class StudentFormScreen extends ConsumerWidget {
  const StudentFormScreen({super.key, required this.institutionId, this.studentId});

  final String institutionId;
  final String? studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (studentId == null) {
      return _StudentForm(institutionId: institutionId, existingStudent: null);
    }

    final studentAsync = ref.watch(studentDetailProvider(studentId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier l\'élève')),
      body: SafeArea(
        child: studentAsync.when(
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
                    onPressed: () => ref.invalidate(studentDetailProvider(studentId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (student) => _StudentForm(institutionId: institutionId, existingStudent: student),
        ),
      ),
    );
  }
}

class _StudentForm extends ConsumerStatefulWidget {
  const _StudentForm({required this.institutionId, required this.existingStudent});

  final String institutionId;
  final Student? existingStudent;

  @override
  ConsumerState<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends ConsumerState<_StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameController = TextEditingController(text: widget.existingStudent?.firstName);
  late final _lastNameController = TextEditingController(text: widget.existingStudent?.lastName);
  late final _guardianNameController = TextEditingController(text: widget.existingStudent?.guardianName);
  late final _guardianPhoneController = TextEditingController(text: widget.existingStudent?.guardianPhone);

  AcademicUnit? _academicUnit;
  DateTime? _dateOfBirth;
  bool _academicUnitInitialized = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingStudent != null;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.existingStudent?.dateOfBirth;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 10),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_academicUnit == null) {
      setState(() => _errorMessage = 'Choisissez une classe.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(schoolRepositoryProvider);

      if (_isEditing) {
        await repository.updateStudent(
          studentId: widget.existingStudent!.id,
          institutionId: widget.institutionId,
          academicUnitId: _academicUnit!.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          guardianName: _guardianNameController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
        );
        ref.invalidate(studentDetailProvider(widget.existingStudent!.id));
      } else {
        await repository.createStudent(
          institutionId: widget.institutionId,
          academicUnitId: _academicUnit!.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          guardianName: _guardianNameController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
        );
      }
      ref.invalidate(studentsProvider(StudentListQuery(institutionId: widget.institutionId)));
      if (_academicUnit != null) {
        ref.invalidate(
          studentsProvider(
            StudentListQuery(institutionId: widget.institutionId, academicUnitId: _academicUnit!.id),
          ),
        );
      }
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unitsAsync = ref.watch(academicUnitsProvider(widget.institutionId));

    return Scaffold(
      appBar: _isEditing ? null : AppBar(title: const Text('Nouvel élève')),
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
                      if (widget.existingStudent != null) ...[
                        _InviteCodeCard(
                          inviteCode: widget.existingStudent!.inviteCode,
                          isClaimed: widget.existingStudent!.userId != null,
                        ),
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
                      Text('Classe', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      unitsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les classes.'),
                        data: (units) {
                          if (!_academicUnitInitialized) {
                            _academicUnitInitialized = true;
                            if (widget.existingStudent != null) {
                              for (final unit in units) {
                                if (unit.id == widget.existingStudent!.academicUnitId) {
                                  _academicUnit = unit;
                                }
                              }
                            }
                          }
                          return DropdownButtonFormField<AcademicUnit>(
                            initialValue: _academicUnit,
                            isExpanded: true,
                            hint: const Text('Choisir une classe'),
                            items: [
                              for (final unit in units)
                                DropdownMenuItem(value: unit, child: Text('${unit.name} (${unit.level})')),
                            ],
                            onChanged: (value) => setState(() => _academicUnit = value),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Date de naissance (optionnel)', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: _pickDateOfBirth,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_rounded)),
                          child: Text(
                            _dateOfBirth == null ? 'Choisir une date' : _formatDate(_dateOfBirth!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _guardianNameController,
                        label: 'Nom du tuteur (optionnel)',
                        prefixIcon: Icons.family_restroom_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _guardianPhoneController,
                        label: 'Téléphone du tuteur (optionnel)',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Inscrire l\'élève',
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

/// See TeacherFormScreen's identical _InviteCodeCard for the rationale
/// (stays visible once claimed; userId marks it used, not the code
/// changing) - duplicated per screen rather than shared, matching this
/// module's existing per-entity duplication convention.
class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.inviteCode, required this.isClaimed});

  final String inviteCode;
  final bool isClaimed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code d\'invitation', style: textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  inviteCode,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isClaimed ? 'Compte déjà activé avec ce code.' : 'Compte pas encore activé.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copier le code',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copié.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
