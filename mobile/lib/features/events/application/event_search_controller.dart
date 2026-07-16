import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/event_search_params.dart';
import '../models/event_search_result.dart';

final eventCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(eventRepositoryProvider).getCities();
});

final eventSearchResultsProvider = FutureProvider.autoDispose.family<List<EventSearchResult>, EventSearchParams>((
  ref,
  params,
) {
  return ref.watch(eventRepositoryProvider).searchEvents(
    cityId: params.cityId,
    category: params.category?.apiValue,
    onOrAfter: params.onOrAfter,
  );
});
