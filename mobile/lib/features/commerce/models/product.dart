class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    required this.currencyId,
    required this.categoryIds,
    required this.images,
    required this.stock,
    required this.isActive,
  });

  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double price;
  final String currencyId;
  final List<String> categoryIds;
  final List<String> images;
  final int stock;
  final bool isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      currencyId: json['currency_id'] as String,
      categoryIds: (json['category_ids'] as List<dynamic>).cast<String>(),
      images: (json['images'] as List<dynamic>).cast<String>(),
      stock: json['stock'] as int,
      isActive: json['is_active'] as bool,
    );
  }
}
