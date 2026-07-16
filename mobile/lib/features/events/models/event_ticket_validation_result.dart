import 'event_ticket.dart';

/// POST /event-tickets/{code}/validate's response - an EventTicket plus
/// the passenger name and ticket category the backend resolves
/// server-side, since there's no general-purpose "look up another
/// user" endpoint for the scanning organizer to call itself. Mirrors
/// transport's TicketValidationResult (passenger_name + seat_number).
class EventTicketValidationResult {
  const EventTicketValidationResult({
    required this.id,
    required this.bookingId,
    required this.eventId,
    required this.ticketTypeId,
    required this.passengerId,
    required this.quantity,
    required this.code,
    required this.status,
    required this.usedAt,
    required this.passengerName,
    required this.ticketCategory,
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
  final String passengerName;
  final String ticketCategory;

  factory EventTicketValidationResult.fromJson(Map<String, dynamic> json) {
    return EventTicketValidationResult(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      eventId: json['event_id'] as String,
      ticketTypeId: json['ticket_type_id'] as String,
      passengerId: json['passenger_id'] as String,
      quantity: json['quantity'] as int,
      code: json['code'] as String,
      status: parseEventTicketStatus(json['status'] as String),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
      passengerName: json['passenger_name'] as String,
      ticketCategory: json['ticket_category'] as String,
    );
  }
}
