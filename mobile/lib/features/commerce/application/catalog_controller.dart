import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_catalog_entry.dart';
import '../models/store.dart';

final categoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) {
  return ref.watch(catalogRepositoryProvider).getCategories();
});

class ProductSearchParams {
  const ProductSearchParams({this.search, this.categoryId});

  final String? search;
  final String? categoryId;

  @override
  bool operator ==(Object other) =>
      other is ProductSearchParams && other.search == search && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}

final productSearchProvider =
    FutureProvider.autoDispose.family<List<ProductCatalogEntry>, ProductSearchParams>((ref, params) {
  return ref
      .watch(catalogRepositoryProvider)
      .searchProducts(search: params.search, categoryId: params.categoryId);
});

final productDetailProvider = FutureProvider.autoDispose.family<Product, String>((ref, productId) {
  return ref.watch(catalogRepositoryProvider).getProduct(productId);
});

final storeDetailProvider = FutureProvider.autoDispose.family<Store, String>((ref, storeId) {
  return ref.watch(catalogRepositoryProvider).getStore(storeId);
});

final storeProductsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, storeId) {
  return ref.watch(catalogRepositoryProvider).getStoreProducts(storeId);
});
