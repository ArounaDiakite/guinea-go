import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Cart writes only for now (used by the "Ajouter au panier" button on
/// the product detail screen) - the read side (getCart) and the cart
/// screen itself land in a later step, once there's something worth
/// displaying a cart badge for.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  Future<void> addItem({required String productId, required int quantity}) {
    return _dio.post<Map<String, dynamic>>(
      '/cart/items',
      data: {'product_id': productId, 'quantity': quantity},
    );
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});
