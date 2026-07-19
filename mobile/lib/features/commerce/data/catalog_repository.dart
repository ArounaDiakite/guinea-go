import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_catalog_entry.dart';
import '../models/store.dart';

/// Passenger-facing reads for the Commerce catalog: categories,
/// products (with their store name resolved for display), stores.
/// Mirrors HotelRepository/EventRepository's role - kept separate from
/// StoreManagerRepository (the write-heavy store_manager surface) the
/// same way HotelRepository and HotelOwnerRepository stay separate.
class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<ProductCategory>> getCategories() async {
    final response = await _dio.get<List<dynamic>>('/categories/', queryParameters: {'limit': 100});
    return response.data!.map((json) => ProductCategory.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Store> getStore(String storeId) async {
    final response = await _dio.get<Map<String, dynamic>>('/stores/$storeId');
    return Store.fromJson(response.data!);
  }

  Future<Product> getProduct(String productId) async {
    final response = await _dio.get<Map<String, dynamic>>('/products/$productId');
    return Product.fromJson(response.data!);
  }

  /// Catalog search: name search and category filter are applied
  /// server-side; each result's store name is resolved afterward
  /// (stores shared by several products in the same page are only
  /// fetched once).
  Future<List<ProductCatalogEntry>> searchProducts({String? search, String? categoryId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/products/',
      queryParameters: {
        'search': ?search,
        'category_id': ?categoryId,
        'limit': 100,
      },
    );
    final products = response.data!.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();

    final storeNameCache = <String, String>{};
    final entries = <ProductCatalogEntry>[];

    for (final product in products) {
      if (!product.isActive) continue;

      final storeName = storeNameCache[product.storeId] ??= (await getStore(product.storeId)).name;
      entries.add(ProductCatalogEntry(product: product, storeName: storeName));
    }

    return entries;
  }

  Future<List<Product>> getStoreProducts(String storeId) async {
    final response = await _dio.get<List<dynamic>>(
      '/stores/$storeId/products',
      queryParameters: {'limit': 100},
    );
    return response.data!.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});
