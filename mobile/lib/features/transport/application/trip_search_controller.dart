import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transport_repository.dart';
import '../../../core/models/city.dart';
import '../models/trip.dart';
import '../models/trip_search_params.dart';

final citiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(transportRepositoryProvider).getCities();
});

final tripSearchResultsProvider = FutureProvider.autoDispose.family<List<TripSearchResult>, TripSearchParams>((
  ref,
  params,
) {
  return ref.watch(transportRepositoryProvider).searchTrips(
    originCityId: params.originCityId,
    destinationCityId: params.destinationCityId,
    date: params.date,
  );
});
