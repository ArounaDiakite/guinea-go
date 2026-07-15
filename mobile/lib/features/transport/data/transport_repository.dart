import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/booking.dart';
import '../models/booking_summary.dart';
import '../models/bus.dart';
import '../models/city.dart';
import '../models/driver.dart';
import '../models/payment.dart';
import '../models/station.dart';
import '../models/transport_company.dart';
import '../models/transport_route.dart';
import '../models/trip.dart';
import '../models/trip_detail.dart';
import '../models/trip_seat.dart';

/// Every read below is public and unauthenticated except the booking/
/// payment endpoints - see backend/app/identity/auth README in the
/// transport module for the full auth matrix.
///
/// The backend's TripResponse/RouteResponse/etc only carry bare ids
/// (company_id, route_id, bus_id, driver_id, origin_station_id, ...) -
/// there is no combined "trip with everything" endpoint. This
/// repository is what stitches a usable screen's worth of data
/// together from several calls, and caches reference data (cities,
/// stations, companies, buses, drivers, routes) in memory for the life
/// of the app session since none of it changes during a booking flow.
class TransportRepository {
  TransportRepository(this._dio);

  final Dio _dio;

  Future<List<City>>? _citiesFuture;
  final Map<String, City> _cityCache = {};
  final Map<String, Station> _stationCache = {};
  final Map<String, TransportCompany> _companyCache = {};
  final Map<String, Bus> _busCache = {};
  final Map<String, Driver> _driverCache = {};
  final Map<String, TransportRoute> _routeCache = {};

  Future<List<City>> getCities() {
    return _citiesFuture ??= _dio.get<List<dynamic>>('/cities/').then((response) {
      final cities = response.data!.map((json) => City.fromJson(json as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final city in cities) {
        _cityCache[city.id] = city;
      }
      return cities;
    });
  }

  Future<City> _cityById(String id) async {
    if (_cityCache.containsKey(id)) return _cityCache[id]!;
    await getCities();
    return _cityCache[id]!;
  }

  Future<List<Station>> _stationsByCity(String cityId) async {
    final response = await _dio.get<List<dynamic>>(
      '/stations/',
      queryParameters: {'city_id': cityId, 'limit': 100},
    );
    final stations = response.data!.map((json) => Station.fromJson(json as Map<String, dynamic>)).toList();
    for (final station in stations) {
      _stationCache[station.id] = station;
    }
    return stations;
  }

  Future<Station> _stationById(String id) async {
    if (_stationCache.containsKey(id)) return _stationCache[id]!;
    final response = await _dio.get<Map<String, dynamic>>('/stations/$id');
    final station = Station.fromJson(response.data!);
    _stationCache[id] = station;
    return station;
  }

  Future<TransportRoute> _routeById(String id) async {
    if (_routeCache.containsKey(id)) return _routeCache[id]!;
    final response = await _dio.get<Map<String, dynamic>>('/routes/$id');
    final route = TransportRoute.fromJson(response.data!);
    _routeCache[id] = route;
    return route;
  }

  Future<TransportCompany> _companyById(String id) async {
    if (_companyCache.containsKey(id)) return _companyCache[id]!;
    final response = await _dio.get<Map<String, dynamic>>('/companies/$id');
    final company = TransportCompany.fromJson(response.data!);
    _companyCache[id] = company;
    return company;
  }

  Future<Bus> _busById(String id) async {
    if (_busCache.containsKey(id)) return _busCache[id]!;
    final response = await _dio.get<Map<String, dynamic>>('/buses/$id');
    final bus = Bus.fromJson(response.data!);
    _busCache[id] = bus;
    return bus;
  }

  Future<Driver> _driverById(String id) async {
    if (_driverCache.containsKey(id)) return _driverCache[id]!;
    final response = await _dio.get<Map<String, dynamic>>('/drivers/$id');
    final driver = Driver.fromJson(response.data!);
    _driverCache[id] = driver;
    return driver;
  }

  /// There is no origin/destination query param on GET /trips/ - the
  /// backend only supports filtering by route_id. So a "city to city"
  /// search here means: find every station in each city, find every
  /// route whose origin/destination station is in that set, then fetch
  /// trips per matching route for the given date. /routes/ is fetched
  /// one page of up to 100 - fine for this app's current scale, but a
  /// real limit if the network ever lists more routes than that.
  Future<List<TripSearchResult>> searchTrips({
    required String originCityId,
    required String destinationCityId,
    required DateTime date,
  }) async {
    final originStations = await _stationsByCity(originCityId);
    final destinationStations = await _stationsByCity(destinationCityId);

    if (originStations.isEmpty || destinationStations.isEmpty) return [];

    final originStationIds = originStations.map((s) => s.id).toSet();
    final destinationStationIds = destinationStations.map((s) => s.id).toSet();

    final routesResponse = await _dio.get<List<dynamic>>('/routes/', queryParameters: {'limit': 100});
    final routes = routesResponse.data!.map((json) => TransportRoute.fromJson(json as Map<String, dynamic>));

    final matchingRoutes = routes.where(
      (route) =>
          originStationIds.contains(route.originStationId) &&
          destinationStationIds.contains(route.destinationStationId),
    );

    final results = <TripSearchResult>[];
    final dateOnly = DateTime(date.year, date.month, date.day);

    for (final route in matchingRoutes) {
      _routeCache[route.id] = route;

      final tripsResponse = await _dio.get<List<dynamic>>(
        '/trips/',
        queryParameters: {
          'route_id': route.id,
          'travel_date': '${dateOnly.year.toString().padLeft(4, '0')}-'
              '${dateOnly.month.toString().padLeft(2, '0')}-'
              '${dateOnly.day.toString().padLeft(2, '0')}',
          'limit': 100,
        },
      );

      final company = await _companyById(route.companyId);
      final originCity = _cityById(originCityId);
      final destinationCity = _cityById(destinationCityId);

      for (final json in tripsResponse.data!) {
        final trip = Trip.fromJson(json as Map<String, dynamic>);
        if (trip.status == TripStatus.cancelled || trip.status == TripStatus.completed) continue;

        results.add(
          TripSearchResult(
            trip: trip,
            route: route,
            company: company,
            originCityName: (await originCity).name,
            destinationCityName: (await destinationCity).name,
          ),
        );
      }
    }

    results.sort((a, b) => a.trip.departureDatetime.compareTo(b.trip.departureDatetime));
    return results;
  }

  Future<TripDetail> getTripDetail(String tripId) async {
    final tripResponse = await _dio.get<Map<String, dynamic>>('/trips/$tripId');
    final trip = Trip.fromJson(tripResponse.data!);

    final route = await _routeById(trip.routeId);
    final company = await _companyById(trip.companyId);
    final bus = await _busById(trip.busId);
    final driver = await _driverById(trip.driverId);
    final originStation = await _stationById(route.originStationId);
    final destinationStation = await _stationById(route.destinationStationId);
    final originCity = await _cityById(originStation.cityId);
    final destinationCity = await _cityById(destinationStation.cityId);

    return TripDetail(
      trip: trip,
      route: route,
      company: company,
      bus: bus,
      driver: driver,
      originStationName: originStation.name,
      originCityName: originCity.name,
      destinationStationName: destinationStation.name,
      destinationCityName: destinationCity.name,
    );
  }

  Future<List<TripSeat>> getTripSeats(String tripId) async {
    final response = await _dio.get<List<dynamic>>('/trips/$tripId/seats');
    final seats = response.data!.map((json) => TripSeat.fromJson(json as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.numericOrder.compareTo(b.numericOrder));
    return seats;
  }

  Future<Booking> createBooking({required String tripId, required String seatId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trips/$tripId/bookings',
      data: {'seat_id': seatId},
    );
    return Booking.fromJson(response.data!);
  }

  Future<Payment> payForBooking({
    required String bookingId,
    required PaymentProvider provider,
    required double amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/bookings/$bookingId/payments',
      data: {'provider': provider.apiValue, 'amount': amount},
    );
    return Payment.fromJson(response.data!);
  }

  Future<List<Booking>> getMyBookings() async {
    final response = await _dio.get<List<dynamic>>('/bookings/me', queryParameters: {'limit': 100});
    return response.data!.map((json) => Booking.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final response = await _dio.delete<Map<String, dynamic>>('/bookings/$bookingId');
    return Booking.fromJson(response.data!);
  }

  /// "Mes réservations" needs a display line per booking (company,
  /// route, seat) - bookings only carry trip_id/seat_id, so this
  /// fetches each referenced trip once (bookings sharing a trip reuse
  /// it) and resolves the seat number from that trip's seat list.
  Future<List<BookingSummary>> getMyBookingsWithDetails() async {
    final bookings = await getMyBookings();
    final tripCache = <String, Trip>{};
    final seatsCache = <String, List<TripSeat>>{};
    final summaries = <BookingSummary>[];

    for (final booking in bookings) {
      final trip = tripCache[booking.tripId] ??=
          Trip.fromJson((await _dio.get<Map<String, dynamic>>('/trips/${booking.tripId}')).data!);
      tripCache[booking.tripId] = trip;

      final route = await _routeById(trip.routeId);
      final company = await _companyById(trip.companyId);
      final originStation = await _stationById(route.originStationId);
      final destinationStation = await _stationById(route.destinationStationId);
      final originCity = await _cityById(originStation.cityId);
      final destinationCity = await _cityById(destinationStation.cityId);

      final seats = seatsCache[booking.tripId] ??= await getTripSeats(booking.tripId);
      TripSeat? seat;
      for (final candidate in seats) {
        if (candidate.seatId == booking.seatId) {
          seat = candidate;
          break;
        }
      }

      summaries.add(
        BookingSummary(
          booking: booking,
          trip: trip,
          companyName: company.name,
          originCityName: originCity.name,
          destinationCityName: destinationCity.name,
          seatNumber: seat?.seatNumber ?? '?',
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

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  return TransportRepository(ref.watch(apiClientProvider));
});
