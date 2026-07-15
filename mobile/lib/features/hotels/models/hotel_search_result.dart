import 'hotel.dart';

/// A hotel stitched together with what a results-list card needs:
/// the cheapest available room's price for the searched dates, and a
/// review average/count if any reviews exist yet.
class HotelSearchResult {
  const HotelSearchResult({
    required this.hotel,
    required this.cityName,
    required this.startingPrice,
    required this.averageRating,
    required this.reviewCount,
  });

  final Hotel hotel;
  final String cityName;
  final double startingPrice;
  final double? averageRating;
  final int reviewCount;
}
