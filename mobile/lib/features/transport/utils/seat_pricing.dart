import '../models/trip_seat.dart';

/// Mirrors the backend's own price_paid calculation (BookingService) so
/// the booking recap screen can show a seat's real price before the
/// booking actually exists server-side - a window seat costs 10% more,
/// everything else is the trip's base price. The booking response
/// remains the authoritative number once it's created; this is only
/// ever shown as a pre-confirmation estimate.
double estimateSeatPrice(double tripPrice, SeatType seatType) {
  final raw = seatType == SeatType.window ? tripPrice * 1.10 : tripPrice;
  return (raw * 100).round() / 100;
}
