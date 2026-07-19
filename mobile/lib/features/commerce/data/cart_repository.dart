import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/cart.dart';

/// The passenger's cart: one per customer, entirely server-side (see
/// backend/app/modules/commerce/cart). Every mutation returns the full
/// updated cart, same shape as getCart, so callers never need a
/// separate re-fetch after a write.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  Future<Cart> getCart() async {
    final response = await _dio.get<Map<String, dynamic>>('/cart/');
    return Cart.fromJson(response.data!);
  }

  Future<Cart> addItem({required String productId, required int quantity}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cart/items',
      data: {'product_id': productId, 'quantity': quantity},
    );
    return Cart.fromJson(response.data!);
  }

  Future<Cart> updateItemQuantity({required String productId, required int quantity}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/cart/items/$productId',
      data: {'quantity': quantity},
    );
    return Cart.fromJson(response.data!);
  }

  Future<Cart> removeItem(String productId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/cart/items/$productId');
    return Cart.fromJson(response.data!);
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});
