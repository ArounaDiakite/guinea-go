import 'ticket_type.dart';

/// What the booking recap screen needs from the detail screen: the
/// chosen ticket type plus the quantity the passenger picked.
class EventBookingSelection {
  const EventBookingSelection({required this.ticketType, required this.quantity, required this.eventName});

  final TicketType ticketType;
  final int quantity;
  final String eventName;
}
