import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_repository.dart';
import '../models/order.dart';
import '../models/order_summary.dart';

final myOrdersProvider = FutureProvider.autoDispose<List<OrderSummary>>((ref) {
  return ref.watch(orderRepositoryProvider).getMyOrdersWithDetails();
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).getOrder(orderId);
});
