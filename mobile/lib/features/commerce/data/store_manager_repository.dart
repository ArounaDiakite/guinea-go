import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/network/api_client.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/order_summary.dart';
import '../models/product.dart';
import '../models/store.dart';

/// Everything a store_manager needs to run their own stores: the
/// stores themselves (a manager may run several, unlike a hotel_owner's
/// single hotel), each store's product catalog, the shared global
/// category taxonomy, and the orders received against a store. Kept
/// separate from CatalogRepository (passenger reads/cart) the same way
/// HotelOwnerRepository stays separate from HotelRepository.
class StoreManagerRepository {
  StoreManagerRepository(this._dio);

  final Dio _dio;

  Future<List<Country>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Store>> getMyStores(String ownerId) async {
    final response = await _dio.get<List<dynamic>>('/stores/', queryParameters: {'owner_id': ownerId, 'limit': 100});
    return response.data!.map((json) => Store.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Store> getStore(String storeId) async {
    final response = await _dio.get<Map<String, dynamic>>('/stores/$storeId');
    return Store.fromJson(response.data!);
  }

  Future<Store> createStore({
    required String name,
    required String phone,
    required String email,
    required String countryId,
    required String cityId,
    required String address,
    String? description,
    String? shippingInfo,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stores/',
      data: {
        'name': name,
        'phone': phone,
        'email': email,
        'country_id': countryId,
        'city_id': cityId,
        'address': address,
        if (description != null && description.isNotEmpty) 'description': description,
        if (shippingInfo != null && shippingInfo.isNotEmpty) 'shipping_info': shippingInfo,
      },
    );
    return Store.fromJson(response.data!);
  }

  Future<List<ProductCategory>> getCategories() async {
    final response = await _dio.get<List<dynamic>>('/categories/', queryParameters: {'limit': 100});
    return response.data!.map((json) => ProductCategory.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<ProductCategory> createCategory({required String name, String? description}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/categories/',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return ProductCategory.fromJson(response.data!);
  }

  Future<List<Product>> getStoreProducts(String storeId) async {
    final response = await _dio.get<List<dynamic>>('/stores/$storeId/products', queryParameters: {'limit': 100});
    return response.data!.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Product> createProduct({
    required String storeId,
    required String name,
    required double price,
    required int stock,
    required List<String> categoryIds,
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/products/',
      data: {
        'store_id': storeId,
        'name': name,
        'price': price,
        'stock': stock,
        'category_ids': categoryIds,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Product.fromJson(response.data!);
  }

  Future<Product> updateProduct({
    required String productId,
    required String storeId,
    required String name,
    required double price,
    required int stock,
    required List<String> categoryIds,
    String? description,
    bool isActive = true,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/products/$productId',
      data: {
        'store_id': storeId,
        'name': name,
        'price': price,
        'stock': stock,
        'category_ids': categoryIds,
        'is_active': isActive,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Product.fromJson(response.data!);
  }

  Future<List<OrderSummary>> getOrdersForStore(String storeId) async {
    final response = await _dio.get<List<dynamic>>('/orders/', queryParameters: {'store_id': storeId, 'limit': 100});
    final store = await getStore(storeId);
    final orders = response.data!.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) {
        final aCreated = a.createdAt;
        final bCreated = b.createdAt;
        if (aCreated == null || bCreated == null) return 0;
        return bCreated.compareTo(aCreated);
      });
    return orders.map((order) => OrderSummary(order: order, storeName: store.name)).toList();
  }
}

final storeManagerRepositoryProvider = Provider<StoreManagerRepository>((ref) {
  return StoreManagerRepository(ref.watch(apiClientProvider));
});
