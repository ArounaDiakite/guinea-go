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
import '../application/catalog_controller.dart';
import '../application/store_manager_controller.dart';
import '../data/store_manager_repository.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Handles both create (productId == null) and edit (productId set) -
/// edit mode watches productDetailProvider to pre-fill the form once
/// the product's current data has loaded, rather than trusting a value
/// passed in via `extra` that could go stale between screens.
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({super.key, required this.storeId, this.productId});

  final String storeId;
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == null) {
      return _ProductForm(storeId: storeId, existingProduct: null);
    }

    final productAsync = ref.watch(productDetailProvider(productId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le produit')),
      body: SafeArea(
        child: productAsync.when(
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
                    onPressed: () => ref.invalidate(productDetailProvider(productId!)),
                  ),
                ],
              ),
            ),
          ),
          data: (product) => _ProductForm(storeId: storeId, existingProduct: product),
        ),
      ),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.storeId, required this.existingProduct});

  final String storeId;
  final Product? existingProduct;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existingProduct?.name);
  late final _priceController = TextEditingController(
    text: widget.existingProduct?.price.toStringAsFixed(0),
  );
  late final _stockController = TextEditingController(text: widget.existingProduct?.stock.toString());
  late final _descriptionController = TextEditingController(text: widget.existingProduct?.description);

  late final Set<String> _selectedCategoryIds = {...?widget.existingProduct?.categoryIds};
  late bool _isActive = widget.existingProduct?.isActive ?? true;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingProduct != null;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
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
      final repository = ref.read(storeManagerRepositoryProvider);

      if (_isEditing) {
        await repository.updateProduct(
          productId: widget.existingProduct!.id,
          storeId: widget.storeId,
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          categoryIds: _selectedCategoryIds.toList(),
          description: _descriptionController.text.trim(),
          isActive: _isActive,
        );
        ref.invalidate(productDetailProvider(widget.existingProduct!.id));
      } else {
        await repository.createProduct(
          storeId: widget.storeId,
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          stock: int.parse(_stockController.text.trim()),
          categoryIds: _selectedCategoryIds.toList(),
          description: _descriptionController.text.trim(),
        );
      }
      ref.invalidate(storeManagedProductsProvider(widget.storeId));
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
    final categoriesAsync = ref.watch(storeManagerCategoriesProvider);

    return Scaffold(
      appBar: _isEditing ? null : AppBar(title: const Text('Nouveau produit')),
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
                        label: 'Nom du produit',
                        prefixIcon: Icons.shopping_bag_outlined,
                        validator: (value) => value == null || value.trim().isEmpty ? 'Le nom est requis.' : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _priceController,
                              label: 'Prix (GNF)',
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
                              controller: _stockController,
                              label: 'Stock',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final stock = int.tryParse(value?.trim() ?? '');
                                if (stock == null || stock < 0) {
                                  return 'Stock invalide.';
                                }
                                return null;
                              },
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Catégories', style: textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) =>
                            const AppErrorBanner(message: 'Impossible de charger les catégories.'),
                        data: (categories) {
                          if (categories.isEmpty) {
                            return Text(
                              'Aucune catégorie disponible. Créez-en une depuis "Catégories".',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            );
                          }
                          return Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final category in categories) _CategoryChip(
                                category: category,
                                selected: _selectedCategoryIds.contains(category.id),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _selectedCategoryIds.add(category.id);
                                  } else {
                                    _selectedCategoryIds.remove(category.id);
                                  }
                                }),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optionnel)',
                        prefixIcon: Icons.notes_outlined,
                        textInputAction: TextInputAction.done,
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: AppSpacing.md),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Visible dans le catalogue'),
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _isEditing ? 'Enregistrer' : 'Ajouter le produit',
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.selected, required this.onSelected});

  final ProductCategory category;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(label: Text(category.name), selected: selected, onSelected: onSelected);
  }
}
