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
import '../application/store_manager_controller.dart';
import '../models/product.dart';

class StoreProductListScreen extends ConsumerWidget {
  const StoreProductListScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(storeManagedProductsProvider(storeId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Produits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hub/store/$storeId/products/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: SafeArea(
        child: productsAsync.when(
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
                    onPressed: () => ref.invalidate(storeManagedProductsProvider(storeId)),
                  ),
                ],
              ),
            ),
          ),
          data: (products) {
            if (products.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun produit enregistré pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _ProductCard(storeId: storeId, product: products[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.storeId, required this.product});

  final String storeId;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final outOfStock = product.stock <= 0;

    return AppCard(
      onTap: () => context.push('/hub/store/$storeId/products/${product.id}/edit'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  formatGnf(product.price),
                  style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                outOfStock ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
                size: 16,
                color: outOfStock ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  outOfStock ? 'Rupture de stock' : '${product.stock} en stock',
                  style: textTheme.bodySmall?.copyWith(color: outOfStock ? AppColors.error : AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!product.isActive) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('Masqué', style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
