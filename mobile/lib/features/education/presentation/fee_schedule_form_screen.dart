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
import '../models/fee_schedule.dart';

/// Handles both create (feeScheduleId == null) and edit, same shape as
/// the other education forms.
class FeeScheduleFormScreen extends ConsumerWidget {
  const FeeScheduleFormScreen({super.key, required this.institutionId, this.feeScheduleId});

  final String institutionId;
  final String? feeScheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feeScheduleId == null) {
      return _FeeScheduleForm(institutionId: institutionId, existingFeeSchedule: null);
    }

    final feeScheduleAsync = ref.watch(feeScheduleDetailProvider(feeScheduleId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier les frais')),
      body: SafeArea(
        child: feeScheduleAsync.when(
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
                    onPressed: () => ref.invalidate(feeScheduleDetailProvider(feeScheduleId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (feeSchedule) =>
              _FeeScheduleForm(institutionId: institutionId, existingFeeSchedule: feeSchedule),
        ),
      ),
    );
  }
}

class _FeeScheduleForm extends ConsumerStatefulWidget {
  const _FeeScheduleForm({required this.institutionId, required this.existingFeeSchedule});

  final String institutionId;
  final FeeSchedule? existingFeeSchedule;

  @override
  ConsumerState<_FeeScheduleForm> createState() => _FeeScheduleFormState();
}

class _FeeScheduleFormState extends ConsumerState<_FeeScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existingFeeSchedule?.name);
  late final _amountController = TextEditingController(
    text: widget.existingFeeSchedule?.amount.toStringAsFixed(0),
  );
  late final _periodController = TextEditingController(text: widget.existingFeeSchedule?.period);

  AcademicUnit? _academicUnit;
  bool _academicUnitInitialized = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingFeeSchedule != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _periodController.dispose();
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
      final name = _nameController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final period = _periodController.text.trim();

      if (_isEditing) {
        await repository.updateFeeSchedule(
          feeScheduleId: widget.existingFeeSchedule!.id,
          institutionId: widget.institutionId,
          academicUnitId: _academicUnit?.id,
          name: name,
          amount: amount,
          period: period,
        );
        ref.invalidate(feeScheduleDetailProvider(widget.existingFeeSchedule!.id));
      } else {
        await repository.createFeeSchedule(
          institutionId: widget.institutionId,
          academicUnitId: _academicUnit?.id,
          name: name,
          amount: amount,
          period: period,
        );
      }
      ref.invalidate(feeSchedulesProvider(widget.institutionId));
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
      appBar: _isEditing ? null : AppBar(title: const Text('Nouveaux frais')),
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
                        label: 'Nom des frais',
                        hint: 'ex : Frais de scolarité, Inscription',
                        prefixIcon: Icons.receipt_long_outlined,
                        validator: (value) => AppValidators.required(value, 'Le nom'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _amountController,
                        label: 'Montant (GNF)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');
                          if (amount == null || amount <= 0) {
                            return 'Montant invalide.';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _periodController,
                        label: 'Période',
                        hint: 'ex : Trimestriel, Annuel, Mensuel',
                        prefixIcon: Icons.event_repeat_outlined,
                        validator: (value) => AppValidators.required(value, 'La période'),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Portée', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      unitsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les classes.'),
                        data: (units) {
                          if (!_academicUnitInitialized) {
                            _academicUnitInitialized = true;
                            final existing = widget.existingFeeSchedule;
                            if (existing?.academicUnitId != null) {
                              for (final unit in units) {
                                if (unit.id == existing!.academicUnitId) _academicUnit = unit;
                              }
                            }
                          }
                          return DropdownButtonFormField<AcademicUnit?>(
                            initialValue: _academicUnit,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<AcademicUnit?>(
                                value: null,
                                child: Text('Tout l\'établissement'),
                              ),
                              for (final unit in units) DropdownMenuItem(value: unit, child: Text(unit.name)),
                            ],
                            onChanged: (value) => setState(() => _academicUnit = value),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Laissez "Tout l\'établissement" pour des frais qui s\'appliquent à tous les élèves, '
                        'ou choisissez une classe pour des frais spécifiques.',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Créer les frais',
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
