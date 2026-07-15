import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/models/currency.dart';
import '../../../core/network/api_client.dart';
import '../models/hotel.dart';
import '../models/hotel_booking.dart';
import '../models/room.dart';

/// Everything a hotel_owner needs to manage their own hotel: the hotel
/// itself, its rooms, and the bookings received against it. Kept
/// separate from HotelRepository (passenger reads/bookings) the same
/// way CompanyRepository stays separate from TransportRepository.
class HotelOwnerRepository {
  HotelOwnerRepository(this._dio);

  final Dio _dio;

  Future<List<Country>> getCountries() async {
    final response = await _dio.get<List<dynamic>>('/countries/');
    return response.data!.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Currency>> getCurrencies() async {
    final response = await _dio.get<List<dynamic>>('/currencies/');
    return response.data!.map((json) => Currency.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// A hotel_owner can in principle own more than one hotel, but this
  /// app only ever manages the first one found for them - same
  /// small-operator assumption as CompanyRepository.getMyCompany.
  Future<Hotel?> getMyHotel(String ownerId) async {
    final response = await _dio.get<List<dynamic>>('/hotels/', queryParameters: {'owner_id': ownerId, 'limit': 1});
    final hotels = response.data!;
    if (hotels.isEmpty) return null;
    return Hotel.fromJson(hotels.first as Map<String, dynamic>);
  }

  Future<Hotel> createHotel({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String countryId,
    required String cityId,
    String? description,
    String? website,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/hotels/',
      data: {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'country_id': countryId,
        'city_id': cityId,
        if (description != null && description.isNotEmpty) 'description': description,
        if (website != null && website.isNotEmpty) 'website': website,
      },
    );
    return Hotel.fromJson(response.data!);
  }

  Future<List<Room>> getRooms(String hotelId) async {
    final response = await _dio.get<List<dynamic>>(
      '/rooms/',
      queryParameters: {'hotel_id': hotelId, 'limit': 100},
    );
    return response.data!.map((json) => Room.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
  }

  Future<Room> createRoom({
    required String hotelId,
    required String roomNumber,
    required RoomType roomType,
    required int capacity,
    required double basePrice,
    String? currencyId,
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms/',
      data: {
        'hotel_id': hotelId,
        'room_number': roomNumber,
        'room_type': roomType.apiValue,
        'capacity': capacity,
        'base_price': basePrice,
        'currency_id': ?currencyId,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Room.fromJson(response.data!);
  }

  /// Toggles a room's availability (AVAILABLE <-> MAINTENANCE) - PUT
  /// requires the full RoomCreate payload, so this resends the room's
  /// existing fields with just `status` changed.
  Future<Room> updateRoomStatus(Room room, RoomStatus status) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/rooms/${room.id}',
      data: {
        'hotel_id': room.hotelId,
        'room_number': room.roomNumber,
        'room_type': room.roomType.apiValue,
        'capacity': room.capacity,
        'base_price': room.basePrice,
        'currency_id': room.currencyId,
        if (room.description != null) 'description': room.description,
        'status': status.apiValue,
      },
    );
    return Room.fromJson(response.data!);
  }

  Future<List<HotelBooking>> getBookingsForHotel(String hotelId) async {
    final response = await _dio.get<List<dynamic>>(
      '/hotel-bookings/',
      queryParameters: {'hotel_id': hotelId, 'limit': 100},
    );
    return response.data!.map((json) => HotelBooking.fromJson(json as Map<String, dynamic>)).toList();
  }
}

final hotelOwnerRepositoryProvider = Provider<HotelOwnerRepository>((ref) {
  return HotelOwnerRepository(ref.watch(apiClientProvider));
});
