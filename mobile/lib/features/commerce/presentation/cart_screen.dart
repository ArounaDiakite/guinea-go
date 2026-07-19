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
import '../application/cart_controller.dart';
import '../data/cart_repository.dart';
import '../models/cart.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panier')),
      body: SafeArea(
        child: cartAsync.when(
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
                    onPressed: () => ref.invalidate(cartProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (cart) {
            if (cart.items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Votre panier est vide.', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            final groups = cart.itemsByStore;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      for (final entry in groups.entries) ...[
                        _StoreGroup(storeName: entry.value.first.storeName, items: entry.value),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total', style: Theme.of(context).textTheme.labelMedium),
                                  Text(
                                    formatGnf(cart.total),
                                    key: const ValueKey('cart-grand-total'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Passer la commande',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => context.push('/hub/commerce/checkout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoreGroup extends StatelessWidget {
  const _StoreGroup({required this.storeName, required this.items});

  final String storeName;
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final storeSubtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  storeName,
                  style: textTheme.titleSmall?.copyWith(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          for (final item in items) ...[
            _CartItemRow(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Text('Sous-total', style: textTheme.bodyMedium),
              const Spacer(),
              Flexible(
                child: Text(
                  formatGnf(storeSubtotal),
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends ConsumerStatefulWidget {
  const _CartItemRow({required this.item});

  final CartItem item;

  @override
  ConsumerState<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends ConsumerState<_CartItemRow> {
  bool _isUpdating = false;

  Future<void> _updateQuantity(int quantity) async {
    setState(() => _isUpdating = true);

    try {
      await ref
          .read(cartRepositoryProvider)
          .updateItemQuantity(productId: widget.item.productId, quantity: quantity);
      ref.invalidate(cartProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiErrorMessage(error))),
      );
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _isUpdating = true);

    try {
      await ref.read(cartRepositoryProvider).removeItem(widget.item.productId);
      ref.invalidate(cartProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiErrorMessage(error))),
      );
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    return Opacity(
      opacity: _isUpdating ? 0.5 : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis, maxLines: 2),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatGnf(item.unitPrice)} / unité',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: ValueKey('cart-item-decrement-${item.productId}'),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    onPressed: _isUpdating || item.quantity <= 1 ? null : () => _updateQuantity(item.quantity - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${item.quantity}',
                      key: ValueKey('cart-item-quantity-${item.productId}'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('cart-item-increment-${item.productId}'),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    onPressed: _isUpdating ? null : () => _updateQuantity(item.quantity + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    key: ValueKey('cart-item-remove-${item.productId}'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                    onPressed: _isUpdating ? null : _remove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              Text(formatGnf(item.subtotal), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
