import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/booking_status.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../application/store_manager_controller.dart';
import '../models/order_summary.dart';

class StoreOrdersReceivedScreen extends ConsumerWidget {
  const StoreOrdersReceivedScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(storeOrdersReceivedProvider(storeId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Commandes reçues')),
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
                    expand: false,
                    onPressed: () => ref.invalidate(storeOrdersReceivedProvider(storeId)),
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
                      Text('Aucune commande reçue pour le moment.', style: textTheme.titleMedium),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _ReceivedOrderCard(summary: orders[index]),
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

class _ReceivedOrderCard extends StatelessWidget {
  const _ReceivedOrderCard({required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final order = summary.order;
    final style = _statusStyles[order.status]!;
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$itemCount article${itemCount > 1 ? 's' : ''}',
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
          const SizedBox(height: AppSpacing.sm),
          for (final item in order.items) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity} × ${item.productName}',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
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
        ],
      ),
    );
  }
}
