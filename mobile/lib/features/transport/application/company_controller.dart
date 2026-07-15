import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../identity/application/auth_controller.dart';
import '../data/company_repository.dart';
import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/models/currency.dart';
import '../models/managed_bus.dart';
import '../models/managed_company.dart';
import '../models/managed_driver.dart';
import '../models/managed_route.dart';
import '../models/managed_schedule.dart';
import '../models/station.dart';
import '../models/trip.dart';

final myCompanyProvider = FutureProvider.autoDispose<ManagedCompany?>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return null;
  return ref.watch(companyRepositoryProvider).getMyCompany(user.id);
});

final companyCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(companyRepositoryProvider).getCountries();
});

final companyCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(companyRepositoryProvider).getCities();
});

final companyCurrenciesProvider = FutureProvider.autoDispose<List<Currency>>((ref) {
  return ref.watch(companyRepositoryProvider).getCurrencies();
});

final companyStationsProvider = FutureProvider.autoDispose<List<Station>>((ref) {
  return ref.watch(companyRepositoryProvider).getStations();
});

final companyBusesProvider = FutureProvider.autoDispose.family<List<ManagedBus>, String>((ref, companyId) {
  return ref.watch(companyRepositoryProvider).getBuses(companyId);
});

final companyDriversProvider = FutureProvider.autoDispose.family<List<ManagedDriver>, String>((ref, companyId) {
  return ref.watch(companyRepositoryProvider).getDrivers(companyId);
});

final companyRoutesProvider = FutureProvider.autoDispose.family<List<ManagedRoute>, String>((ref, companyId) {
  return ref.watch(companyRepositoryProvider).getRoutes(companyId);
});

final companySchedulesProvider = FutureProvider.autoDispose.family<List<ManagedSchedule>, String>((ref, companyId) {
  return ref.watch(companyRepositoryProvider).getSchedules(companyId);
});

final companyTripsProvider = FutureProvider.autoDispose.family<List<Trip>, String>((ref, companyId) {
  return ref.watch(companyRepositoryProvider).getCompanyTrips(companyId);
});
