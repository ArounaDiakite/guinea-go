class TripSearchParams {
  const TripSearchParams({
    required this.originCityId,
    required this.originCityName,
    required this.destinationCityId,
    required this.destinationCityName,
    required this.date,
  });

  final String originCityId;
  final String originCityName;
  final String destinationCityId;
  final String destinationCityName;
  final DateTime date;

  @override
  bool operator ==(Object other) {
    return other is TripSearchParams &&
        other.originCityId == originCityId &&
        other.destinationCityId == destinationCityId &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => Object.hash(originCityId, destinationCityId, date.year, date.month, date.day);
}
