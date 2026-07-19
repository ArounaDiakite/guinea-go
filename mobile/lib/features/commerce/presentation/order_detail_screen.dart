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
import '../../payments/models/payment.dart';
import '../application/order_controller.dart';
import '../data/order_repository.dart';
import '../models/order.dart';
import '../models/order_summary.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.summary});

  final OrderSummary summary;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isCancelling = false;
  // Captured up front in didChangeDependencies (context is guaranteed
  // safe there) - `ref` itself can't be used inside dispose() (Riverpod
  // ties it to this element's BuildContext, which is unsafe to touch
  // once unmounting starts), but a plain ProviderContainer reference
  // obtained earlier still is.
  late ProviderContainer _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    // "Mes commandes" may still be sitting further down the Navigator
    // stack (checkout lands there before this screen is ever reached),
    // and go_router reuses that same page - and its autoDispose
    // myOrdersProvider - across separate context.go() calls to the
    // identical path rather than rebuilding it, so the list never
    // notices this order's status changed (e.g. a payment confirming)
    // on its own. Invalidate on the way out, whatever the reason for
    // leaving - cancelled, paid, or just backing out to double-check
    // something - so the list is never stale when it's next shown.
    //
    // Deferred to a microtask: go_router's context.go() can unmount
    // several pages in the same frame (this screen and PaymentScreen
    // both go at once when paying), and invalidating synchronously
    // mid-unmount trips Riverpod's/Flutter's "widget tree locked"
    // guard. A microtask runs right after that pass finishes.
    Future.microtask(() => _container.invalidate(myOrdersProvider));
    super.dispose();
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Retour')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Annuler la commande')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      await ref.read(orderRepositoryProvider).cancelOrder(widget.summary.order.id);
      ref.invalidate(orderDetailProvider(widget.summary.order.id));
      ref.invalidate(myOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commande annulée.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.summary.order.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la commande')),
      body: SafeArea(
        child: orderAsync.when(
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
                    onPressed: () => ref.invalidate(orderDetailProvider(widget.summary.order.id)),
                  ),
                ],
              ),
            ),
          ),
          data: (order) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _OrderInfoCard(order: order, storeName: widget.summary.storeName),
              if (order.status == BookingStatus.pendingPayment) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Payer',
                  icon: Icons.payment_rounded,
                  onPressed: () => context.push(
                    '/hub/commerce/orders/${order.id}/payment',
                    extra: PaymentRequest(
                      bookingId: order.id,
                      pricePaid: order.total,
                      bookingType: PaymentBookingType.order,
                      confirmedRoute: '/hub/commerce/orders',
                    ),
                  ),
                ),
              ],
              if (order.status == BookingStatus.pendingPayment || order.status == BookingStatus.confirmed) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Annuler la commande',
                  variant: AppButtonVariant.secondary,
                  isLoading: _isCancelling,
                  onPressed: _cancel,
                ),
              ],
            ],
          ),
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

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.order, required this.storeName});

  final Order order;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyles[order.status]!;

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
          const Divider(height: AppSpacing.lg),
          for (final item in order.items) ...[
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
              Text('Total', style: textTheme.titleSmall),
              const Spacer(),
              Flexible(
                child: Text(
                  formatGnf(order.total),
                  style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
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
