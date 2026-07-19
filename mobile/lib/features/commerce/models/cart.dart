class CartItem {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.storeName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String productId;
  final String productName;
  final String storeId;
  final String storeName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      storeId: json['store_id'] as String,
      storeName: json['store_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class Cart {
  const Cart({required this.id, required this.items, required this.total});

  final String id;
  final List<CartItem> items;
  final double total;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// The cart screen groups items by store (checkout will create one
  /// Order per store), preserving each store's first-appearance order
  /// rather than resorting alphabetically.
  Map<String, List<CartItem>> get itemsByStore {
    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.storeId, () => []).add(item);
    }
    return grouped;
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toDouble(),
    );
  }
}
