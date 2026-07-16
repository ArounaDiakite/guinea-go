enum EventTicketStatus { valid, used, cancelled, unknown }

EventTicketStatus parseEventTicketStatus(String raw) {
  switch (raw) {
    case 'VALID':
      return EventTicketStatus.valid;
    case 'USED':
      return EventTicketStatus.used;
    case 'CANCELLED':
      return EventTicketStatus.cancelled;
    default:
      return EventTicketStatus.unknown;
  }
}

class EventTicket {
  const EventTicket({
    required this.id,
    required this.bookingId,
    required this.eventId,
    required this.ticketTypeId,
    required this.passengerId,
    required this.quantity,
    required this.code,
    required this.status,
    required this.usedAt,
  });

  final String id;
  final String bookingId;
  final String eventId;
  final String ticketTypeId;
  final String passengerId;
  final int quantity;
  final String code;
  final EventTicketStatus status;
  final DateTime? usedAt;

  factory EventTicket.fromJson(Map<String, dynamic> json) {
    return EventTicket(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      eventId: json['event_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      passengerId: json['passenger_id'] as String,
      quantity: json['quantity'] as int,
      code: json['code'] as String,
      status: parseEventTicketStatus(json['status'] as String),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
    );
  }
}
