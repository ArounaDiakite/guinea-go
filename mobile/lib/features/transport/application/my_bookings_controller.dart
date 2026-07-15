import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/transport_repository.dart';
import '../models/booking_summary.dart';

final myBookingsProvider = FutureProvider.autoDispose<List<BookingSummary>>((ref) {
  return ref.watch(transportRepositoryProvider).getMyBookingsWithDetails();
});
