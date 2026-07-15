enum TicketStatus { valid, used, cancelled, unknown }

TicketStatus _parseTicketStatus(String raw) {
  switch (raw) {
    case 'VALID':
      return TicketStatus.valid;
    case 'USED':
      return TicketStatus.used;
    case 'CANCELLED':
      return TicketStatus.cancelled;
    default:
      return TicketStatus.unknown;
  }
}

class Ticket {
  const Ticket({
    required this.id,
    required this.bookingId,
    required this.tripId,
    required this.seatId,
    required this.passengerId,
    required this.code,
    required this.status,
    required this.usedAt,
  });

  final String id;
  final String bookingId;
  final String tripId;
  final String seatId;
  final String passengerId;
  final String code;
  final TicketStatus status;
  final DateTime? usedAt;

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      tripId: json['trip_id'] as String,
      seatId: json['seat_id'] as String,
      passengerId: json['passenger_id'] as String,
      code: json['code'] as String,
      status: _parseTicketStatus(json['status'] as String),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
    );
  }
}
