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
import '../application/hotel_owner_controller.dart';
import '../data/hotel_owner_repository.dart';
import '../models/room.dart';

class HotelRoomFormScreen extends ConsumerStatefulWidget {
  const HotelRoomFormScreen({super.key, required this.hotelId});

  final String hotelId;

  @override
  ConsumerState<HotelRoomFormScreen> createState() => _HotelRoomFormScreenState();
}

class _HotelRoomFormScreenState extends ConsumerState<HotelRoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _capacityController = TextEditingController(text: '2');
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  RoomType _roomType = RoomType.simple;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roomNumberController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
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
      await ref.read(hotelOwnerRepositoryProvider).createRoom(
        hotelId: widget.hotelId,
        roomNumber: _roomNumberController.text.trim(),
        roomType: _roomType,
        capacity: int.parse(_capacityController.text.trim()),
        basePrice: double.parse(_priceController.text.trim()),
        description: _descriptionController.text.trim(),
      );
      ref.invalidate(hotelRoomsManagedProvider(widget.hotelId));
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
      appBar: AppBar(title: const Text('Nouvelle chambre')),
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
                        controller: _roomNumberController,
                        label: 'Numéro de chambre',
                        validator: (value) => AppValidators.required(value, 'Le numéro de chambre'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Type de chambre', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<RoomType>(
                        initialValue: _roomType,
                        isExpanded: true,
                        items: [
                          for (final type in RoomType.values)
                            DropdownMenuItem(value: type, child: Text(type.label)),
                        ],
                        onChanged: (value) => setState(() => _roomType = value ?? _roomType),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _capacityController,
                              label: 'Capacité',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final capacity = int.tryParse(value?.trim() ?? '');
                                if (capacity == null || capacity < 1 || capacity > 20) {
                                  return 'Entre 1 et 20.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              controller: _priceController,
                              label: 'Prix par nuit',
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
                AppButton(label: 'Ajouter la chambre', isLoading: _isSubmitting, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
