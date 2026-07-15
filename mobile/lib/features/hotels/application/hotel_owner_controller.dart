import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/models/currency.dart';
import '../../identity/application/auth_controller.dart';
import '../data/hotel_owner_repository.dart';
import '../models/hotel.dart';
import '../models/hotel_booking.dart';
import '../models/room.dart';

final myHotelProvider = FutureProvider.autoDispose<Hotel?>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return null;
  return ref.watch(hotelOwnerRepositoryProvider).getMyHotel(user.id);
});

final hotelOwnerCountriesProvider = FutureProvider.autoDispose<List<Country>>((ref) {
  return ref.watch(hotelOwnerRepositoryProvider).getCountries();
});

final hotelOwnerCitiesProvider = FutureProvider.autoDispose<List<City>>((ref) {
  return ref.watch(hotelOwnerRepositoryProvider).getCities();
});

final hotelOwnerCurrenciesProvider = FutureProvider.autoDispose<List<Currency>>((ref) {
  return ref.watch(hotelOwnerRepositoryProvider).getCurrencies();
});

final hotelRoomsManagedProvider = FutureProvider.autoDispose.family<List<Room>, String>((ref, hotelId) {
  return ref.watch(hotelOwnerRepositoryProvider).getRooms(hotelId);
});

final hotelBookingsReceivedProvider = FutureProvider.autoDispose.family<List<HotelBooking>, String>((
  ref,
  hotelId,
) {
  return ref.watch(hotelOwnerRepositoryProvider).getBookingsForHotel(hotelId);
});
