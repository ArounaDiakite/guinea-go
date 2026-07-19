import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_status.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/order_controller.dart';
import '../data/order_repository.dart';
import '../models/order_summary.dart';

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  final _cancellingIds = <String>{};

  Future<void> _cancel(OrderSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: Text('${summary.storeName}, ${formatGnf(summary.order.total)}. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Retour')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Annuler la commande')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingIds.add(summary.order.id));

    try {
      await ref.read(orderRepositoryProvider).cancelOrder(summary.order.id);
      ref.invalidate(myOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande annulée.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(summary.order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: SafeArea(
        child: ordersAsync.when(
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
                    onPressed: () => ref.invalidate(myOrdersProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 48),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucune commande pour le moment.', style: textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Vos commandes apparaîtront ici.',
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final summary = orders[index];
                return _OrderCard(
                  summary: summary,
                  isCancelling: _cancellingIds.contains(summary.order.id),
                  onCancel: () => _cancel(summary),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

const _statusStyles = {
  BookingStatus.pendingPayment: _StatusStyle('En attente de paiement', AppColors.accentDark, AppColors.accentLight),
  BookingStatus.confirmed: _StatusStyle('Confirmée', AppColors.secondaryDark, AppColors.secondaryLight),
  BookingStatus.cancelled: _StatusStyle('Annulée', AppColors.textSecondary, AppColors.surfaceVariant),
  BookingStatus.expired: _StatusStyle('Expirée', AppColors.error, AppColors.errorLight),
  BookingStatus.unknown: _StatusStyle('Statut inconnu', AppColors.textSecondary, AppColors.surfaceVariant),
};

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.summary, required this.isCancelling, required this.onCancel});

  final OrderSummary summary;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final order = summary.order;
    final style = _statusStyles[order.status]!;
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final canCancel = order.status == BookingStatus.pendingPayment || order.status == BookingStatus.confirmed;

    return AppCard(
      onTap: () => context.push('/hub/commerce/orders/${order.id}', extra: summary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.storeName,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    style.label,
                    style: textTheme.labelSmall?.copyWith(color: style.foreground),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$itemCount article${itemCount > 1 ? 's' : ''}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Spacer(),
              Flexible(
                child: Text(
                  formatGnf(order.total),
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (order.status == BookingStatus.pendingPayment) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Payer',
              icon: Icons.payment_rounded,
              // Goes to the order detail screen (which has its own
              // "Payer" button), not straight to the payment route -
              // /orders/:orderId/payment is nested under :orderId, so
              // go_router builds OrderDetailScreen as an ancestor page
              // in the stack too and would try to cast this same
              // `extra` as an OrderSummary if pushed here directly.
              onPressed: () => context.push('/hub/commerce/orders/${order.id}', extra: summary),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Annuler la commande',
              variant: AppButtonVariant.secondary,
              isLoading: isCancelling,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
