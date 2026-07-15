import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../data/hotel_repository.dart';
import '../models/hotel_search_params.dart';
import '../models/hotel_search_result.dart';

final hotelCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(hotelRepositoryProvider).getCities();
});

final hotelSearchResultsProvider = FutureProvider.autoDispose.family<List<HotelSearchResult>, HotelSearchParams>((
  ref,
  params,
) {
  return ref.watch(hotelRepositoryProvider).searchHotels(
    cityId: params.cityId,
    cityName: params.cityName,
    checkIn: params.checkIn,
    checkOut: params.checkOut,
  );
});
