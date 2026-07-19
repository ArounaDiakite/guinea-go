import 'product.dart';

/// A product plus the store name it belongs to - the catalog list
/// shows "image, nom, prix, boutique" per row, but ProductResponse only
/// carries store_id, so the repository resolves each product's store
/// once (stores shared across entries reuse the cached name) and pairs
/// them together here.
class ProductCatalogEntry {
  const ProductCatalogEntry({required this.product, required this.storeName});

  final Product product;
  final String storeName;
}
