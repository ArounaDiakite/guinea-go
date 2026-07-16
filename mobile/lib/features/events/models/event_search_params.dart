import 'event.dart';

/// Every filter is optional - unlike Hotels (which needs check_in/
/// check_out to know what's bookable at all), Events browsing works
/// fine with just a city, just a category, or nothing at all.
class EventSearchParams {
  const EventSearchParams({this.cityId, this.cityName, this.category, this.onOrAfter});

  final String? cityId;
  final String? cityName;
  final EventCategory? category;

  /// Client-side filter only - GET /events/ has no date query param on
  /// the backend, so this is applied after fetching (see
  /// EventRepository.searchEvents).
  final DateTime? onOrAfter;

  @override
  bool operator ==(Object other) {
    return other is EventSearchParams &&
        other.cityId == cityId &&
        other.category == category &&
        other.onOrAfter?.year == onOrAfter?.year &&
        other.onOrAfter?.month == onOrAfter?.month &&
        other.onOrAfter?.day == onOrAfter?.day;
  }

  @override
  int get hashCode => Object.hash(cityId, category, onOrAfter?.year, onOrAfter?.month, onOrAfter?.day);
}
