import '../../../core/models/booking_status.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

/// One Order per store, created atomically for the whole cart by
/// POST /orders/checkout - status/expiry follow the same
/// PENDING_PAYMENT -> CONFIRMED/CANCELLED/EXPIRED machine as every
/// other payable booking (see core/models/booking_status.dart).
class Order {
  const Order({
    required this.id,
    required this.storeId,
    required this.items,
    required this.total,
    required this.status,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String storeId;
  final List<OrderItem> items;
  final double total;
  final BookingStatus status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      items: (json['items'] as List<dynamic>).map((json) => OrderItem.fromJson(json as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toDouble(),
      status: parseBookingStatus(json['status'] as String),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
