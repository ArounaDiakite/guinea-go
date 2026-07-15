/// Family key for hotelAvailableRoomsProvider - a hotel plus the stay
/// dates being searched for.
class HotelRoomsQuery {
  const HotelRoomsQuery({required this.hotelId, required this.checkIn, required this.checkOut});

  final String hotelId;
  final DateTime checkIn;
  final DateTime checkOut;

  @override
  bool operator ==(Object other) {
    return other is HotelRoomsQuery &&
        other.hotelId == hotelId &&
        other.checkIn.year == checkIn.year &&
        other.checkIn.month == checkIn.month &&
        other.checkIn.day == checkIn.day &&
        other.checkOut.year == checkOut.year &&
        other.checkOut.month == checkOut.month &&
        other.checkOut.day == checkOut.day;
  }

  @override
  int get hashCode => Object.hash(
    hotelId,
    checkIn.year,
    checkIn.month,
    checkIn.day,
    checkOut.year,
    checkOut.month,
    checkOut.day,
  );
}
