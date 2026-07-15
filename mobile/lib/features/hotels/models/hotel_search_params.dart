class HotelSearchParams {
  const HotelSearchParams({
    required this.cityId,
    required this.cityName,
    required this.checkIn,
    required this.checkOut,
  });

  final String cityId;
  final String cityName;
  final DateTime checkIn;
  final DateTime checkOut;

  @override
  bool operator ==(Object other) {
    return other is HotelSearchParams &&
        other.cityId == cityId &&
        other.checkIn.year == checkIn.year &&
        other.checkIn.month == checkIn.month &&
        other.checkIn.day == checkIn.day &&
        other.checkOut.year == checkOut.year &&
        other.checkOut.month == checkOut.month &&
        other.checkOut.day == checkOut.day;
  }

  @override
  int get hashCode => Object.hash(
    cityId,
    checkIn.year,
    checkIn.month,
    checkIn.day,
    checkOut.year,
    checkOut.month,
    checkOut.day,
  );
}
