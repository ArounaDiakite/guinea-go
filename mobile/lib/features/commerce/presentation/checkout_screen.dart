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
import '../data/order_repository.dart';
import '../models/cart.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _confirmOrder() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // One Order per store is created atomically from the whole cart -
      // see backend/app/modules/commerce/orders/service.py::checkout.
      await ref.read(orderRepositoryProvider).checkout();
      ref.invalidate(cartProvider);
      if (!mounted) return;
      // Replaces checkout in the stack (context.go, not push) - same
      // "no going back to a now-stale intermediate screen" reasoning as
      // PaymentScreen's own confirmed-state navigation.
      context.go('/hub/commerce/orders');
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = extractApiErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Récapitulatif de commande')),
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
                  child: Text(
                    'Votre panier est vide.',
                    style: Theme.of(context).textTheme.titleMedium,
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
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.accentDark, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                groups.length > 1
                                    ? '${groups.length} commandes seront créées, une par boutique.'
                                    : '1 commande sera créée, une par boutique.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(color: AppColors.accentDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final entry in groups.entries) ...[
                        _StoreRecap(storeName: entry.value.first.storeName, items: entry.value),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppErrorBanner(message: _errorMessage!),
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
                            Text('Total', style: Theme.of(context).textTheme.labelMedium),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                formatGnf(cart.total),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Confirmer la commande',
                          isLoading: _isSubmitting,
                          onPressed: _confirmOrder,
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

class _StoreRecap extends StatelessWidget {
  const _StoreRecap({required this.storeName, required this.items});

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity} × ${item.productName}',
                    style: textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    formatGnf(item.subtotal),
                    style: textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Text('Sous-total', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
