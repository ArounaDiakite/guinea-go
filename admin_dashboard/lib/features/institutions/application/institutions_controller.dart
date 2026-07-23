import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../data/institutions_repository.dart';

final institutionCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(institutionsRepositoryProvider).getCountries();
});

final institutionCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(institutionsRepositoryProvider).getCities();
});
