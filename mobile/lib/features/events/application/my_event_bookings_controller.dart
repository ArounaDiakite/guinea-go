import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_repository.dart';
import '../models/event_booking_summary.dart';

final myEventBookingsProvider = FutureProvider.autoDispose<List<EventBookingSummary>>((ref) {
  return ref.watch(eventRepositoryProvider).getMyBookingsWithDetails();
});
