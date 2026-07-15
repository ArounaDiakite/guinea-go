import 'hotel_booking.dart';

/// A hotel booking stitched with just enough hotel/room context to
/// render one row in "Mes réservations d'hôtel" - the transport
/// equivalent of BookingSummary.
class HotelBookingSummary {
  const HotelBookingSummary({
    required this.booking,
    required this.hotelName,
    required this.roomNumber,
    required this.roomTypeLabel,
  });

  final HotelBooking booking;
  final String hotelName;
  final String roomNumber;
  final String roomTypeLabel;
}
