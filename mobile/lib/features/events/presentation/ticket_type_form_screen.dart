import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/event_organizer_controller.dart';
import '../data/event_organizer_repository.dart';
import '../models/ticket_type.dart';

class TicketTypeFormScreen extends ConsumerStatefulWidget {
  const TicketTypeFormScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketTypeFormScreen> createState() => _TicketTypeFormScreenState();
}

class _TicketTypeFormScreenState extends ConsumerState<TicketTypeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '50');
  final _descriptionController = TextEditingController();

  TicketCategory _category = TicketCategory.standard;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(eventOrganizerRepositoryProvider).createTicketType(
        eventId: widget.eventId,
        category: _category,
        basePrice: double.parse(_priceController.text.trim()),
        quantityTotal: int.parse(_quantityController.text.trim()),
        description: _descriptionController.text.trim(),
      );
      ref.invalidate(eventTicketTypesManagedProvider(widget.eventId));
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
      appBar: AppBar(title: const Text('Nouveau type de billet')),
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
                      Text('Catégorie', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<TicketCategory>(
                        initialValue: _category,
                        isExpanded: true,
                        items: [
                          for (final value in TicketCategory.values)
                            DropdownMenuItem(value: value, child: Text(value.label)),
                        ],
                        onChanged: (value) => setState(() => _category = value ?? _category),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _priceController,
                              label: 'Prix',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                final price = double.tryParse(value?.trim() ?? '');
                                if (price == null || price <= 0) {
                                  return 'Prix invalide.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _quantityController,
                              label: 'Quantité',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final quantity = int.tryParse(value?.trim() ?? '');
                                if (quantity == null || quantity < 1) {
                                  return 'Au moins 1.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnel)',
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Ajouter le type de billet', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
