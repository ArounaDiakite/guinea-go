import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/school_controller.dart';
import '../data/school_repository.dart';
import '../models/grade.dart';
import '../models/subject.dart';

/// The API has no GET-single-grade endpoint (only create/list/update),
/// so unlike every other education form there's nothing to fetch by id
/// here - the full existing Grade, when editing, has to travel in as a
/// value the caller already has in hand (from the list it's showing),
/// via `extra`, rather than a `gradeId` path param + detail provider.
class GradeFormArgs {
  const GradeFormArgs({required this.institutionId, this.existingGrade});

  final String institutionId;
  final Grade? existingGrade;
}

class GradeFormScreen extends ConsumerStatefulWidget {
  const GradeFormScreen({super.key, required this.studentId, required this.args});

  final String studentId;
  final GradeFormArgs args;

  @override
  ConsumerState<GradeFormScreen> createState() => _GradeFormScreenState();
}

class _GradeFormScreenState extends ConsumerState<GradeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _valueController = TextEditingController(text: widget.args.existingGrade?.value.toString());
  late final _coefficientController = TextEditingController(
    text: widget.args.existingGrade?.coefficient.toString(),
  );

  Subject? _subject;
  bool _subjectInitialized = false;
  late Period _period = widget.args.existingGrade?.period ?? Period.t1;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.args.existingGrade != null;

  @override
  void dispose() {
    _valueController.dispose();
    _coefficientController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subject == null) {
      setState(() => _errorMessage = 'Choisissez une matière.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(schoolRepositoryProvider);
      final value = double.parse(_valueController.text.trim());
      final coefficient = double.parse(_coefficientController.text.trim());

      if (_isEditing) {
        await repository.updateGrade(
          studentId: widget.studentId,
          gradeId: widget.args.existingGrade!.id,
          subjectId: _subject!.id,
          value: value,
          coefficient: coefficient,
          period: _period,
        );
      } else {
        await repository.addGrade(
          studentId: widget.studentId,
          subjectId: _subject!.id,
          value: value,
          coefficient: coefficient,
          period: _period,
        );
      }
      for (final period in <Period?>[null, Period.t1, Period.t2, Period.t3]) {
        ref.invalidate(gradesProvider(GradesQuery(studentId: widget.studentId, period: period)));
      }
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
    final subjectsAsync = ref.watch(subjectsProvider(widget.args.institutionId));

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier la note' : 'Nouvelle note')),
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
                      Text('Matière', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      subjectsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les matières.'),
                        data: (subjects) {
                          if (!_subjectInitialized) {
                            _subjectInitialized = true;
                            final existing = widget.args.existingGrade;
                            if (existing != null) {
                              for (final subject in subjects) {
                                if (subject.id == existing.subjectId) _subject = subject;
                              }
                            }
                          }
                          if (subjects.isEmpty) {
                            return Text(
                              'Créez d\'abord une matière pour pouvoir noter cet élève.',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            );
                          }
                          return DropdownButtonFormField<Subject>(
                            initialValue: _subject,
                            isExpanded: true,
                            hint: const Text('Choisir une matière'),
                            items: [
                              for (final subject in subjects)
                                DropdownMenuItem(value: subject, child: Text(subject.name)),
                            ],
                            onChanged: (value) => setState(() => _subject = value),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Trimestre', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<Period>(
                        initialValue: _period,
                        isExpanded: true,
                        items: [
                          for (final period in Period.values)
                            DropdownMenuItem(value: period, child: Text(period.label)),
                        ],
                        onChanged: (value) => setState(() => _period = value ?? _period),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _valueController,
                              label: 'Note / 20',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                final parsed = double.tryParse(value?.trim() ?? '');
                                if (parsed == null || parsed < 0 || parsed > 20) {
                                  return 'Note invalide (0 à 20).';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _coefficientController,
                              label: 'Coefficient',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                final parsed = double.tryParse(value?.trim() ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'Coefficient invalide.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Ajouter la note',
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
