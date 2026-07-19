import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/catalog_controller.dart';
import '../data/cart_repository.dart';
import '../models/product.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détails du produit')),
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
                    onPressed: () => ref.invalidate(productDetailProvider(productId)),
                  ),
                ],
              ),
            ),
          ),
          data: (product) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _ProductInfoCard(product: product),
              const SizedBox(height: AppSpacing.lg),
              _AddToCartCard(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  const _ProductInfoCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final soldOut = product.stock <= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: textTheme.headlineSmall, overflow: TextOverflow.ellipsis, maxLines: 2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      formatGnf(product.price),
                      style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                soldOut ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
                size: 16,
                color: soldOut ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  soldOut ? 'Rupture de stock' : '${product.stock} en stock',
                  style: textTheme.bodySmall?.copyWith(color: soldOut ? AppColors.error : AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StoreLink(storeId: product.storeId),
          if (product.description != null && product.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(product.description!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _StoreLink extends ConsumerWidget {
  const _StoreLink({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final textTheme = Theme.of(context).textTheme;

    return storeAsync.when(
      loading: () => const SizedBox(height: 0),
      error: (error, stackTrace) => const SizedBox(height: 0),
      data: (store) => InkWell(
        onTap: () => context.push('/hub/commerce/stores/$storeId'),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                store.name,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.primary, decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _AddToCartCard extends ConsumerStatefulWidget {
  const _AddToCartCard({required this.product});

  final Product product;

  @override
  ConsumerState<_AddToCartCard> createState() => _AddToCartCardState();
}

class _AddToCartCardState extends ConsumerState<_AddToCartCard> {
  int _quantity = 1;
  bool _isSubmitting = false;

  int get _maxQuantity {
    const maxPerAdd = 20;
    final cap = widget.product.stock < maxPerAdd ? widget.product.stock : maxPerAdd;
    return cap < 1 ? 0 : cap;
  }

  Future<void> _addToCart() async {
    setState(() => _isSubmitting = true);

    try {
      await ref.read(cartRepositoryProvider).addItem(productId: widget.product.id, quantity: _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajouté au panier.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final soldOut = widget.product.stock <= 0;

    if (soldOut) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Quantité', style: textTheme.bodyMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Text('$_quantity', style: textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Ajouter au panier',
            icon: Icons.add_shopping_cart_rounded,
            isLoading: _isSubmitting,
            onPressed: _addToCart,
          ),
        ],
      ),
    );
  }
}
