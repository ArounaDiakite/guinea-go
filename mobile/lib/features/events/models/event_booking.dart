import '../../../core/models/booking_status.dart';

export '../../../core/models/booking_status.dart';

class EventBooking {
  const EventBooking({
    required this.id,
    required this.eventId,
    required this.ticketTypeId,
    required this.passengerId,
    required this.quantity,
    required this.pricePaid,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String ticketTypeId;
  final String passengerId;
  final int quantity;
  final double pricePaid;
  final BookingStatus status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory EventBooking.fromJson(Map<String, dynamic> json) {
    return EventBooking(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      passengerId: json['passenger_id'] as String,
      quantity: json['quantity'] as int,
      pricePaid: (json['price_paid'] as num).toDouble(),
      status: parseBookingStatus(json['status'] as String),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
