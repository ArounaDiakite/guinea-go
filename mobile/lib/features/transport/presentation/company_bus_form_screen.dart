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
import '../models/managed_bus.dart';

class CompanyBusFormScreen extends ConsumerStatefulWidget {
  const CompanyBusFormScreen({super.key, required this.companyId});

  final String companyId;

  @override
  ConsumerState<CompanyBusFormScreen> createState() => _CompanyBusFormScreenState();
}

class _CompanyBusFormScreenState extends ConsumerState<CompanyBusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationController = TextEditingController();
  final _fleetNumberController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  final _seatCapacityController = TextEditingController(text: '30');

  BusType _busType = BusType.standard;
  bool _airConditioning = false;
  bool _wifi = false;
  bool _usbCharging = false;
  bool _toilet = false;
  bool _television = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _registrationController.dispose();
    _fleetNumberController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _seatCapacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(companyRepositoryProvider).createBus(
        companyId: widget.companyId,
        registrationNumber: _registrationController.text.trim(),
        fleetNumber: _fleetNumberController.text.trim(),
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        manufactureYear: int.parse(_yearController.text.trim()),
        seatCapacity: int.parse(_seatCapacityController.text.trim()),
        busType: _busType,
        airConditioning: _airConditioning,
        wifi: _wifi,
        usbCharging: _usbCharging,
        toilet: _toilet,
        television: _television,
      );
      ref.invalidate(companyBusesProvider(widget.companyId));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau bus')),
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
                        controller: _registrationController,
                        label: 'Numéro d\'immatriculation',
                        validator: (value) => AppValidators.required(value, 'L\'immatriculation'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _fleetNumberController,
                        label: 'Numéro de flotte',
                        validator: (value) => AppValidators.required(value, 'Le numéro de flotte'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _brandController,
                              label: 'Marque',
                              validator: (value) => AppValidators.required(value, 'La marque'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _modelController,
                              label: 'Modèle',
                              validator: (value) => AppValidators.required(value, 'Le modèle'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _yearController,
                              label: 'Année',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final year = int.tryParse(value?.trim() ?? '');
                                if (year == null || year < 1980 || year > 2100) {
                                  return 'Année invalide.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _seatCapacityController,
                              label: 'Capacité (sièges)',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final capacity = int.tryParse(value?.trim() ?? '');
                                if (capacity == null || capacity < 1 || capacity > 100) {
                                  return 'Entre 1 et 100.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Type de bus', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<BusType>(
                        initialValue: _busType,
                        isExpanded: true,
                        items: [
                          for (final type in BusType.values)
                            DropdownMenuItem(value: type, child: Text(type.label)),
                        ],
                        onChanged: (value) => setState(() => _busType = value ?? _busType),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Équipements', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      _EquipmentSwitch(
                        label: 'Climatisation',
                        value: _airConditioning,
                        onChanged: (value) => setState(() => _airConditioning = value),
                      ),
                      _EquipmentSwitch(
                        label: 'Wi-Fi',
                        value: _wifi,
                        onChanged: (value) => setState(() => _wifi = value),
                      ),
                      _EquipmentSwitch(
                        label: 'Prises USB',
                        value: _usbCharging,
                        onChanged: (value) => setState(() => _usbCharging = value),
                      ),
                      _EquipmentSwitch(
                        label: 'Toilettes',
                        value: _toilet,
                        onChanged: (value) => setState(() => _toilet = value),
                      ),
                      _EquipmentSwitch(
                        label: 'Télévision',
                        value: _television,
                        onChanged: (value) => setState(() => _television = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Ajouter le bus', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipmentSwitch extends StatelessWidget {
  const _EquipmentSwitch({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
