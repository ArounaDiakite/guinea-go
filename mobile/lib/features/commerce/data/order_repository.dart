import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import 'catalog_repository.dart';

/// Passenger-facing checkout/order history. Checkout consumes the whole
/// cart server-side and returns one Order per store (see
/// backend/app/modules/commerce/orders/service.py::checkout) - there's
/// no separate "create order" call per store from the client.
class OrderRepository {
  OrderRepository(this._dio, this._catalogRepository);

  final Dio _dio;
  final CatalogRepository _catalogRepository;

  Future<List<Order>> checkout() async {
    final response = await _dio.post<List<dynamic>>('/orders/checkout');
    return response.data!.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>('/orders/$orderId');
    return Order.fromJson(response.data!);
  }

  Future<List<Order>> getMyOrders() async {
    final response = await _dio.get<List<dynamic>>('/orders/me', queryParameters: {'limit': 100});
    return response.data!.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Order> cancelOrder(String orderId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/orders/$orderId');
    return Order.fromJson(response.data!);
  }

  /// "Mes commandes" needs a display line per order (store name) -
  /// orders only carry store_id, so this resolves each referenced
  /// store once (orders sharing a store reuse it).
  Future<List<OrderSummary>> getMyOrdersWithDetails() async {
    final orders = await getMyOrders();
    final storeNameCache = <String, String>{};
    final summaries = <OrderSummary>[];

    for (final order in orders) {
      final storeName =
          storeNameCache[order.storeId] ??= (await _catalogRepository.getStore(order.storeId)).name;
      summaries.add(OrderSummary(order: order, storeName: storeName));
    }

    summaries.sort((a, b) {
      final aCreated = a.order.createdAt;
      final bCreated = b.order.createdAt;
      if (aCreated == null || bCreated == null) return 0;
      return bCreated.compareTo(aCreated);
    });

    return summaries;
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider), ref.watch(catalogRepositoryProvider));
});
