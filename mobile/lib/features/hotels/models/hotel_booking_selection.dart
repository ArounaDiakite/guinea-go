import 'hotel_stay.dart';
import 'room.dart';

/// What the booking recap screen needs from the detail screen: the
/// chosen room plus the stay dates it was found available for.
class HotelBookingSelection {
  const HotelBookingSelection({required this.room, required this.stay});

  final Room room;
  final HotelStay stay;
}
