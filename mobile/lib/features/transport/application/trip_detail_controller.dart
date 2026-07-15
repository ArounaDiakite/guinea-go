import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transport_repository.dart';
import '../models/trip_detail.dart';
import '../models/trip_seat.dart';

final tripDetailProvider = FutureProvider.autoDispose.family<TripDetail, String>((ref, tripId) {
  return ref.watch(transportRepositoryProvider).getTripDetail(tripId);
});

final tripSeatsProvider = FutureProvider.autoDispose.family<List<TripSeat>, String>((ref, tripId) {
  return ref.watch(transportRepositoryProvider).getTripSeats(tripId);
});
