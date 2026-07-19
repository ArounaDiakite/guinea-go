import 'order.dart';

/// An order plus the store name it belongs to - "Mes commandes" shows a
/// display line per order (store name, item count, total, status), but
/// OrderResponse only carries store_id.
class OrderSummary {
  const OrderSummary({required this.order, required this.storeName});

  final Order order;
  final String storeName;
}
