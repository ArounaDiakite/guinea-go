import 'event.dart';

/// An event stitched together with what a results-list card needs:
/// the cheapest ticket type still available, and a review average/
/// count if any reviews exist yet.
class EventSearchResult {
  const EventSearchResult({
    required this.event,
    required this.cityName,
    required this.startingPrice,
    required this.averageRating,
    required this.reviewCount,
  });

  final Event event;
  final String cityName;
  final double? startingPrice;
  final double? averageRating;
  final int reviewCount;
}
