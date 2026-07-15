import 'booking.dart';
import 'trip.dart';

/// A booking stitched together with just enough trip/route/company
/// context to render one row in "Mes réservations" - deliberately
/// lighter than TripDetail since the history list doesn't need bus/
/// driver info.
class BookingSummary {
  const BookingSummary({
    required this.booking,
    required this.trip,
    required this.companyName,
    required this.originCityName,
    required this.destinationCityName,
    required this.seatNumber,
  });

  final Booking booking;
  final Trip trip;
  final String companyName;
  final String originCityName;
  final String destinationCityName;
  final String seatNumber;
}
