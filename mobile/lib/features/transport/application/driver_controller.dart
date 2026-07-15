import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transport_repository.dart';
import '../models/driver.dart';
import '../models/trip.dart';

final myDriverProfileProvider = FutureProvider.autoDispose<Driver>((ref) {
  return ref.watch(transportRepositoryProvider).getMyDriverProfile();
});

final assignedTripsProvider = FutureProvider.autoDispose<List<TripSearchResult>>((ref) {
  return ref.watch(transportRepositoryProvider).getAssignedTrips();
});
