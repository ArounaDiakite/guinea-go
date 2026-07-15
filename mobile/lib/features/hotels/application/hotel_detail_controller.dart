import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hotel_repository.dart';
import '../models/hotel.dart';
import '../models/hotel_rooms_query.dart';
import '../models/room.dart';

final hotelDetailProvider = FutureProvider.autoDispose.family<Hotel, String>((ref, hotelId) {
  return ref.watch(hotelRepositoryProvider).getHotel(hotelId);
});

final hotelAvailableRoomsProvider = FutureProvider.autoDispose.family<List<Room>, HotelRoomsQuery>((ref, query) {
  return ref.watch(hotelRepositoryProvider).getAvailableRooms(
    hotelId: query.hotelId,
    checkIn: query.checkIn,
    checkOut: query.checkOut,
  );
});

final hotelReviewSummaryProvider = FutureProvider.autoDispose.family<(double?, int), String>((ref, hotelId) {
  return ref.watch(hotelRepositoryProvider).getHotelReviewSummary(hotelId);
});
