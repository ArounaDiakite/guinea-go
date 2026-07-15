import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hotel_repository.dart';
import '../models/hotel_booking_summary.dart';

final myHotelBookingsProvider = FutureProvider.autoDispose<List<HotelBookingSummary>>((ref) {
  return ref.watch(hotelRepositoryProvider).getMyBookingsWithDetails();
});
