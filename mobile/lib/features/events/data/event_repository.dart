import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/city.dart';
import '../../../core/network/api_client.dart';
import '../models/event.dart';
import '../models/event_booking.dart';
import '../models/event_booking_summary.dart';
import '../models/event_search_result.dart';
import '../models/ticket_type.dart';

/// Passenger-facing reads/writes for the Events module: search, detail,
/// booking, payment handoff, history. Mirrors HotelRepository's role
/// and shape - kept separate from EventOrganizerRepository (the
/// write-heavy event_organizer management surface) the same way
/// HotelRepository and HotelOwnerRepository stay separate.
class EventRepository {
  EventRepository(this._dio);

  final Dio _dio;

  final Map<String, City> _cityCache = {};

  Future<List<City>> getCities() async {
    final response = await _dio.get<List<dynamic>>('/cities/');
    final cities = response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final city in cities) {
      _cityCache[city.id] = city;
    }
    return cities;
  }

  Future<City> _cityById(String id) async {
    if (_cityCache.containsKey(id)) return _cityCache[id]!;
    await getCities();
    return _cityCache[id]!;
  }

  Future<(double?, int)> _reviewSummary(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reviews/',
      queryParameters: {'target_type': 'event', 'target_id': eventId},
    );
    final data = response.data!;
    final average = data['average_rating'] as num?;
    return (average?.toDouble(), data['count'] as int);
  }

  Future<List<TicketType>> getTicketTypes(String eventId) async {
    final response = await _dio.get<List<dynamic>>(
      '/ticket-types/',
      queryParameters: {'event_id': eventId, 'limit': 100},
    );
    return response.data!.map((json) => TicketType.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.basePrice.compareTo(b.basePrice));
  }

  /// city_id and category are applied server-side; onOrAfter has no
  /// backend query param equivalent, so it's applied here after
  /// fetching. Events with no ticket types yet, or every ticket type
  /// sold out, are still shown (startingPrice null) - unlike Hotels,
  /// there's no mandatory date range that makes an unbookable result
  /// meaningless to display.
  Future<List<EventSearchResult>> searchEvents({
    String? cityId,
    String? category,
    DateTime? onOrAfter,
  }) async {
    final eventsResponse = await _dio.get<List<dynamic>>(
      '/events/',
      queryParameters: {
        'city_id': ?cityId,
        'category': ?category,
        'limit': 100,
      },
    );
    var events = eventsResponse.data!.map((json) => Event.fromJson(json as Map<String, dynamic>)).toList();

    if (onOrAfter != null) {
      final cutoff = DateTime(onOrAfter.year, onOrAfter.month, onOrAfter.day);
      events = events.where((event) {
        final eventDay = DateTime(event.startDatetime.year, event.startDatetime.month, event.startDatetime.day);
        return !eventDay.isBefore(cutoff);
      }).toList();
    }

    final results = <EventSearchResult>[];

    for (final event in events) {
      final ticketTypes = await getTicketTypes(event.id);
      final availableTicketTypes = ticketTypes.where((t) => t.quantityAvailable > 0);
      final startingPrice = availableTicketTypes.isEmpty
          ? null
          : availableTicketTypes.map((t) => t.basePrice).reduce((a, b) => a < b ? a : b);

      final (averageRating, reviewCount) = await _reviewSummary(event.id);
      final cityName = (await _cityById(event.cityId)).name;

      results.add(
        EventSearchResult(
          event: event,
          cityName: cityName,
          startingPrice: startingPrice,
          averageRating: averageRating,
          reviewCount: reviewCount,
        ),
      );
    }

    return results;
  }

  Future<Event> getEvent(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>('/events/$eventId');
    return Event.fromJson(response.data!);
  }

  Future<(double?, int)> getEventReviewSummary(String eventId) => _reviewSummary(eventId);

  Future<EventBooking> createBooking({required String ticketTypeId, required int quantity}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ticket-types/$ticketTypeId/bookings',
      data: {'quantity': quantity},
    );
    return EventBooking.fromJson(response.data!);
  }

  Future<List<EventBooking>> getMyBookings() async {
    final response = await _dio.get<List<dynamic>>('/event-bookings/me', queryParameters: {'limit': 100});
    return response.data!.map((json) => EventBooking.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<EventBooking> cancelBooking(String bookingId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/event-bookings/$bookingId');
    return EventBooking.fromJson(response.data!);
  }

  Future<TicketType> _getTicketType(String ticketTypeId) async {
    final response = await _dio.get<Map<String, dynamic>>('/ticket-types/$ticketTypeId');
    return TicketType.fromJson(response.data!);
  }

  /// "Mes billets" needs a display line per booking (event name/venue/
  /// date, ticket category) - bookings only carry event_id/
  /// ticket_type_id, so this resolves each referenced event/ticket
  /// type once (bookings sharing one reuse it).
  Future<List<EventBookingSummary>> getMyBookingsWithDetails() async {
    final bookings = await getMyBookings();
    final eventCache = <String, Event>{};
    final ticketTypeCache = <String, TicketType>{};
    final summaries = <EventBookingSummary>[];

    for (final booking in bookings) {
      final event = eventCache[booking.eventId] ??= await getEvent(booking.eventId);
      final ticketType = ticketTypeCache[booking.ticketTypeId] ??= await _getTicketType(booking.ticketTypeId);

      summaries.add(
        EventBookingSummary(
          booking: booking,
          eventName: event.name,
          eventVenue: event.venue,
          eventStartDatetime: event.startDatetime,
          ticketCategoryLabel: ticketType.category.label,
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
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(apiClientProvider));
});
