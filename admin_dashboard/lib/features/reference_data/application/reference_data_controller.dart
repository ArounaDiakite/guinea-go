import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reference_data_repository.dart';
import '../models/reference_data.dart';

final currenciesProvider = FutureProvider.autoDispose<List<CurrencyRecord>>((ref) {
  return ref.watch(referenceDataRepositoryProvider).getCurrencies();
});

final referenceCountriesProvider = FutureProvider.autoDispose<List<CountryRecord>>((ref) {
  return ref.watch(referenceDataRepositoryProvider).getCountries();
});

final referenceCitiesProvider = FutureProvider.autoDispose<List<CityRecord>>((ref) {
  return ref.watch(referenceDataRepositoryProvider).getCities();
});
