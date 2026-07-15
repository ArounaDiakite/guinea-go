import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/network/api_client.dart';
import '../models/hotel.dart';
import '../models/hotel_booking.dart';
import '../models/hotel_booking_summary.dart';
import '../models/hotel_search_result.dart';
import '../models/room.dart';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Passenger-facing reads/writes for the Hotels module: search, detail,
/// booking, payment handoff, history. Mirrors TransportRepository's
/// role and shape - kept separate from HotelOwnerRepository (the
/// write-heavy hotel_owner management surface) the same way
/// TransportRepository and CompanyRepository stay separate.
class HotelRepository {
  HotelRepository(this._dio);

  final Dio _dio;

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    return response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<(double?, int)> _reviewSummary(String hotelId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reviews/',
      queryParameters: {'target_type': 'hotel', 'target_id': hotelId},
    );
    final data = response.data!;
    final average = data['average_rating'] as num?;
    return (average?.toDouble(), data['count'] as int);
  }

  /// One hotel search: hotels in the given city, each with its cheapest
  /// room available for [checkIn, checkOut), review average if any -
  /// hotels with no room available for those dates are left out
  /// entirely rather than shown as unbookable.
  Future<List<HotelSearchResult>> searchHotels({
    required String cityId,
    required String cityName,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final hotelsResponse = await _dio.get<List<dynamic>>(
      '/hotels/',
      queryParameters: {'city_id': cityId, 'limit': 100},
    );
    final hotels = hotelsResponse.data!.map((json) => Hotel.fromJson(json as Map<String, dynamic>));

    final results = <HotelSearchResult>[];

    for (final hotel in hotels) {
      final roomsResponse = await _dio.get<List<dynamic>>(
        '/rooms/',
        queryParameters: {
          'hotel_id': hotel.id,
          'status': 'AVAILABLE',
          'check_in': _isoDate(checkIn),
          'check_out': _isoDate(checkOut),
          'limit': 100,
        },
      );
      final rooms = roomsResponse.data!.map((json) => Room.fromJson(json as Map<String, dynamic>)).toList();
      if (rooms.isEmpty) continue;

      final startingPrice = rooms.map((room) => room.basePrice).reduce((a, b) => a < b ? a : b);
      final (averageRating, reviewCount) = await _reviewSummary(hotel.id);

      results.add(
        HotelSearchResult(
          hotel: hotel,
          cityName: cityName,
          startingPrice: startingPrice,
          averageRating: averageRating,
          reviewCount: reviewCount,
        ),
      );
    }

    return results;
  }

  Future<Hotel> getHotel(String hotelId) async {
    final response = await _dio.get<Map<String, dynamic>>('/hotels/$hotelId');
    return Hotel.fromJson(response.data!);
  }

  Future<List<Room>> getAvailableRooms({
    required String hotelId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/rooms/',
      queryParameters: {
        'hotel_id': hotelId,
        'status': 'AVAILABLE',
        'check_in': _isoDate(checkIn),
        'check_out': _isoDate(checkOut),
        'limit': 100,
      },
    );
    return response.data!.map((json) => Room.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.basePrice.compareTo(b.basePrice));
  }

  Future<(double?, int)> getHotelReviewSummary(String hotelId) => _reviewSummary(hotelId);

  Future<HotelBooking> createBooking({
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/rooms/$roomId/bookings',
      data: {'check_in': _isoDate(checkIn), 'check_out': _isoDate(checkOut)},
    );
    return HotelBooking.fromJson(response.data!);
  }

  Future<List<HotelBooking>> getMyBookings() async {
    final response = await _dio.get<List<dynamic>>('/hotel-bookings/me', queryParameters: {'limit': 100});
    return response.data!.map((json) => HotelBooking.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<HotelBooking> cancelBooking(String bookingId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/hotel-bookings/$bookingId');
    return HotelBooking.fromJson(response.data!);
  }

  /// "Mes réservations d'hôtel" needs a display line per booking (hotel
  /// name, room number/type) - bookings only carry hotel_id/room_id, so
  /// this resolves each referenced hotel/room once (bookings sharing a
  /// hotel/room reuse it).
  Future<List<HotelBookingSummary>> getMyBookingsWithDetails() async {
    final bookings = await getMyBookings();
    final hotelCache = <String, Hotel>{};
    final roomCache = <String, Room>{};
    final summaries = <HotelBookingSummary>[];

    for (final booking in bookings) {
      final hotel = hotelCache[booking.hotelId] ??= await getHotel(booking.hotelId);
      final room = roomCache[booking.roomId] ??= await _getRoom(booking.roomId);

      summaries.add(
        HotelBookingSummary(
          booking: booking,
          hotelName: hotel.name,
          roomNumber: room.roomNumber,
          roomTypeLabel: room.roomType.label,
        ),
      );
    }

    summaries.sort((a, b) {
      final aCreated = a.booking.createdAt;
      final bCreated = b.booking.createdAt;
      if (aCreated == null || bCreated == null) return 0;
      return bCreated.compareTo(aCreated);
    });

    return summaries;
  }

  Future<Room> _getRoom(String roomId) async {
    final response = await _dio.get<Map<String, dynamic>>('/rooms/$roomId');
    return Room.fromJson(response.data!);
  }
}

final hotelRepositoryProvider = Provider<HotelRepository>((ref) {
  return HotelRepository(ref.watch(apiClientProvider));
});
