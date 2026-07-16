import 'event_booking.dart';

/// A booking stitched with just enough event/ticket-type context to
/// render one row in "Mes billets" - the events equivalent of
/// transport's BookingSummary / hotels' HotelBookingSummary.
class EventBookingSummary {
  const EventBookingSummary({
    required this.booking,
    required this.eventName,
    required this.eventVenue,
    required this.eventStartDatetime,
    required this.ticketCategoryLabel,
  });

  final EventBooking booking;
  final String eventName;
  final String eventVenue;
  final DateTime eventStartDatetime;
  final String ticketCategoryLabel;
}
