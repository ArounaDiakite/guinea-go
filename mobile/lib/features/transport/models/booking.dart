enum BookingStatus { pendingPayment, confirmed, cancelled, expired, unknown }

BookingStatus parseBookingStatus(String raw) {
  switch (raw) {
    case 'PENDING_PAYMENT':
      return BookingStatus.pendingPayment;
    case 'CONFIRMED':
      return BookingStatus.confirmed;
    case 'CANCELLED':
      return BookingStatus.cancelled;
    case 'EXPIRED':
      return BookingStatus.expired;
    default:
      return BookingStatus.unknown;
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.tripId,
    required this.seatId,
    required this.passengerId,
    required this.status,
    required this.pricePaid,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String seatId;
  final String passengerId;
  final BookingStatus status;
  final double pricePaid;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      seatId: json['seat_id'] as String,
      passengerId: json['passenger_id'] as String,
      status: parseBookingStatus(json['status'] as String),
      pricePaid: (json['price_paid'] as num).toDouble(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
