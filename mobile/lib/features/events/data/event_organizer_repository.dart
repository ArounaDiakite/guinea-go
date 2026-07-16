import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/models/country.dart';
import '../../../core/models/currency.dart';
import '../../../core/network/api_client.dart';
import '../models/event.dart';
import '../models/event_booking.dart';
import '../models/event_ticket_validation_result.dart';
import '../models/ticket_type.dart';

String _isoDatetime(DateTime dateTime) => dateTime.toIso8601String();

/// Everything an event_organizer needs to manage their own events: the
/// events themselves (an organizer can run several, unlike a
/// hotel_owner's single hotel), each event's ticket types, and the
/// bookings received against them. Kept separate from EventRepository
/// (passenger reads/bookings) the same way HotelOwnerRepository stays
/// separate from HotelRepository.
class EventOrganizerRepository {
  EventOrganizerRepository(this._dio);

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

  Future<List<Event>> getMyEvents(String organizerId) async {
    final response = await _dio.get<List<dynamic>>(
      '/events/',
      queryParameters: {'organizer_id': organizerId, 'limit': 100},
    );
    return response.data!.map((json) => Event.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));
  }

  Future<Event> getEvent(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$eventId');
    return Event.fromJson(response.data!);
  }

  Future<Event> createEvent({
    required String name,
    required String venue,
    required String countryId,
    required String cityId,
    required DateTime startDatetime,
    required DateTime endDatetime,
    required EventCategory category,
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/',
      data: {
        'name': name,
        'venue': venue,
        'country_id': countryId,
        'city_id': cityId,
        'start_datetime': _isoDatetime(startDatetime),
        'end_datetime': _isoDatetime(endDatetime),
        'category': category.apiValue,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Event.fromJson(response.data!);
  }

  Future<List<TicketType>> getTicketTypes(String eventId) async {
    final response = await _dio.get<List<dynamic>>(
      '/ticket-types/',
      queryParameters: {'event_id': eventId, 'limit': 100},
    );
    return response.data!.map((json) => TicketType.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<TicketType> createTicketType({
    required String eventId,
    required TicketCategory category,
    required double basePrice,
    required int quantityTotal,
    String? currencyId,
    String? description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ticket-types/',
      data: {
        'event_id': eventId,
        'category': category.apiValue,
        'base_price': basePrice,
        'quantity_total': quantityTotal,
        'currency_id': ?currencyId,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return TicketType.fromJson(response.data!);
  }

  Future<List<EventBooking>> getBookingsForEvent(String eventId) async {
    final response = await _dio.get<List<dynamic>>(
      '/event-bookings/',
      queryParameters: {'event_id': eventId, 'limit': 100},
    );
    return response.data!.map((json) => EventBooking.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<EventTicketValidationResult> validateTicket(String code) async {
    final response = await _dio.post<Map<String, dynamic>>('/event-tickets/$code/validate');
    return EventTicketValidationResult.fromJson(response.data!);
  }
}

final eventOrganizerRepositoryProvider = Provider<EventOrganizerRepository>((ref) {
  return EventOrganizerRepository(ref.watch(apiClientProvider));
});
