import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../identity/application/auth_controller.dart';
import '../data/store_manager_repository.dart';
import '../models/category.dart';
import '../models/order_summary.dart';
import '../models/product.dart';
import '../models/store.dart';

final myStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return [];
  return ref.watch(storeManagerRepositoryProvider).getMyStores(user.id);
});

final storeManagerCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(storeManagerRepositoryProvider).getCountries();
});

final storeManagerCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(storeManagerRepositoryProvider).getCities();
});

final storeManagerCategoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) {
  return ref.watch(storeManagerRepositoryProvider).getCategories();
});

final storeManagedProductsProvider = FutureProvider.autoDispose.family<List<Product>, String>((ref, storeId) {
  return ref.watch(storeManagerRepositoryProvider).getStoreProducts(storeId);
});

final storeOrdersReceivedProvider = FutureProvider.autoDispose.family<List<OrderSummary>, String>((ref, storeId) {
  return ref.watch(storeManagerRepositoryProvider).getOrdersForStore(storeId);
});
