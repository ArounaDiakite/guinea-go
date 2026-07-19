class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.description,
    this.categoryParentId,
  });

  final String id;
  final String name;
  final String? description;
  final String? categoryParentId;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryParentId: json['category_parent_id'] as String?,
    );
  }
}
