import 'ticket.dart';

/// POST /tickets/{code}/validate's response - a Ticket plus the
/// passenger name and seat number the backend resolves server-side,
/// since there's no general-purpose "look up another user" endpoint
/// for the scanning driver to call itself.
class TicketValidationResult {
  const TicketValidationResult({
    required this.id,
    required this.bookingId,
    required this.tripId,
    required this.seatId,
    required this.passengerId,
    required this.code,
    required this.status,
    required this.usedAt,
    required this.passengerName,
    required this.seatNumber,
  });

  final String id;
  final String bookingId;
  final String tripId;
  final String seatId;
  final String passengerId;
  final String code;
  final TicketStatus status;
  final DateTime? usedAt;
  final String passengerName;
  final String seatNumber;

  factory TicketValidationResult.fromJson(Map<String, dynamic> json) {
    return TicketValidationResult(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      tripId: json['trip_id'] as String,
      seatId: json['seat_id'] as String,
      passengerId: json['passenger_id'] as String,
      code: json['code'] as String,
      status: parseTicketStatus(json['status'] as String),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
      passengerName: json['passenger_name'] as String,
      seatNumber: json['seat_number'] as String,
    );
  }
}
