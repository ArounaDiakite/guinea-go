import '../../../core/models/booking_status.dart';

export '../../../core/models/booking_status.dart';

class HotelBooking {
  const HotelBooking({
    required this.id,
    required this.hotelId,
    required this.roomId,
    required this.passengerId,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.pricePaid,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String hotelId;
  final String roomId;
  final String passengerId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final double pricePaid;
  final BookingStatus status;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory HotelBooking.fromJson(Map<String, dynamic> json) {
    return HotelBooking(
      id: json['id'] as String,
      hotelId: json['hotel_id'] as String,
      roomId: json['room_id'] as String,
      passengerId: json['passenger_id'] as String,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      nights: json['nights'] as int,
      pricePaid: (json['price_paid'] as num).toDouble(),
      status: parseBookingStatus(json['status'] as String),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}
