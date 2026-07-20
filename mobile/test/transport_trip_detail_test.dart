// Real end-to-end test against the live local backend - no HTTP
// mocking. Builds its own dedicated company/bus/driver/route/schedule/
// trip fixture in setUpAll (mirroring transport_search_test.dart and
// transport_ticket_test.dart) rather than targeting the seeded "Sily
// Express" morning trip directly by a hardcoded id - that trip's
// absolute travel_date drifts into the past exactly like any other
// fixed-date fixture would, the same failure mode already fixed
// elsewhere in this suite. The bus/driver fixture data below (brand,
// model, driver name, air conditioning, seat capacity) intentionally
// matches what the old seeded fixture used to have, so the screen
// assertions below didn't need to change shape - only the company
// name is unique per run, since scoping that one assertion to this
// run's own fixture is what actually removes the shared/drifting
// resource.
//
// The reserved-seat fixture is created fresh in setUpAll (a real
// booking via a throwaway account) rather than relying on a seat
// reserved once by hand outside the test - a PENDING_PAYMENT booking
// expires after BOOKING_PAYMENT_TIMEOUT_MINUTES (10 min by default),
// so a fixture created once and left in the database would silently
// stop being reserved the next time this suite happens to run.
// Likewise the "available" seats used for selection are discovered at
// runtime rather than hardcoded.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/transport/models/trip_seat.dart';
import 'package:guinea_go/features/transport/presentation/trip_detail_screen.dart';
import 'package:guinea_go/core/utils/currency.dart';
import 'package:guinea_go/features/transport/utils/seat_pricing.dart';

const _ownerEmail = 'company_owner_e2e_fixture@test.com';
const _ownerPassword = 'TestPass123!';

void setUpMockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        default:
          return null;
      }
    },
  );
}

Widget buildTestApp(String tripId) {
  final router = GoRouter(
    initialLocation: '/hub/transport/trips/$tripId',
    routes: [
      GoRoute(
        path: '/hub/transport/trips/:tripId',
        builder: (context, state) => TripDetailScreen(tripId: state.pathParameters['tripId']!),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options ownerAuthHeader;

  late String companyName;
  late String companyId;
  late String routeId;
  late String tripId;
  late double tripPrice;
  late String reservedSeatNumber;
  late String firstPickSeatNumber;
  late String firstPickPriceText;
  late String secondPickSeatNumber;
  late String secondPickPriceText;

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    companyName = 'Trip Detail E2E $uniqueSuffix';

    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _ownerEmail, 'password': _ownerPassword},
    );
    final token = loginResponse.data!['access_token'] as String;
    ownerAuthHeader = Options(headers: {'Authorization': 'Bearer $token'});

    final countriesResponse = await setupDio.get<List<dynamic>>('/countries/');
    final guinea = countriesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['code'] == 'GN');

    final citiesResponse = await setupDio.get<List<dynamic>>('/cities/', queryParameters: {'limit': 100});
    final conakryCity = citiesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Conakry');

    final companyResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/',
      data: {
        'name': companyName,
        'company_type': 'BUS',
        'phone': '+224633000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'trip_detail_e2e_$uniqueSuffix@test.com',
        'address': 'Kaloum, Conakry',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
      },
      options: ownerAuthHeader,
    );
    companyId = companyResponse.data!['id'] as String;

    final busResponse = await setupDio.post<Map<String, dynamic>>(
      '/buses/',
      data: {
        'company_id': companyId,
        'registration_number': 'RC-TD-$uniqueSuffix',
        'fleet_number': 'F-TD-$uniqueSuffix',
        'brand': 'Mercedes-Benz',
        'model': 'Sprinter',
        'manufacture_year': 2024,
        'seat_capacity': 30,
        'bus_type': 'STANDARD',
        'air_conditioning': true,
      },
      options: ownerAuthHeader,
    );
    final busId = busResponse.data!['id'] as String;
    await setupDio.post<void>('/buses/$busId/generate-seats', options: ownerAuthHeader);

    final driverResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': 'Ibrahima',
        'last_name': 'Camara',
        'email': 'trip_detail_e2e_driver_$uniqueSuffix@test.com',
        'phone': '+224634000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': 'TestPass123!',
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-TD-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-TD-$uniqueSuffix',
          'license_category': 'D',
          'license_expiry_date': _isoDate(DateTime.now().add(const Duration(days: 730))),
          'years_of_experience': 5,
        },
      },
      options: ownerAuthHeader,
    );
    final driverId = (driverResponse.data!['driver'] as Map<String, dynamic>)['id'] as String;

    final stationsResponse = await setupDio.get<List<dynamic>>('/stations/', queryParameters: {'limit': 100});
    final stations = stationsResponse.data!.cast<Map<String, dynamic>>();
    final originStation = stations.firstWhere((s) => s['name'] == 'Conakry Central Bus Station');
    final destinationStation = stations.firstWhere((s) => s['name'] == 'Kankan Gare Routiere');

    final routeResponse = await setupDio.post<Map<String, dynamic>>(
      '/routes/',
      data: {
        'company_id': companyId,
        'route_code': 'TD-$uniqueSuffix',
        'name': 'Conakry - Kankan Trip Detail E2E $uniqueSuffix',
        'origin_station_id': originStation['id'],
        'destination_station_id': destinationStation['id'],
        'distance_km': 620,
        'estimated_duration_minutes': 540,
        'base_price': 250000,
      },
      options: ownerAuthHeader,
    );
    routeId = routeResponse.data!['id'] as String;

    final scheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '07:30:00',
        'operating_days': [
          'MONDAY',
          'TUESDAY',
          'WEDNESDAY',
          'THURSDAY',
          'FRIDAY',
          'SATURDAY',
          'SUNDAY',
        ],
      },
      options: ownerAuthHeader,
    );

    final tripResponse = await setupDio.post<Map<String, dynamic>>(
      '/trips/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'schedule_id': scheduleResponse.data!['id'],
        'bus_id': busId,
        'driver_id': driverId,
        'travel_date': _isoDate(DateTime.now()),
        'price': 250000,
      },
      options: ownerAuthHeader,
    );
    tripId = tripResponse.data!['id'] as String;
    tripPrice = (tripResponse.data!['price'] as num).toDouble();

    final seatsResponse = await setupDio.get<List<dynamic>>('/trips/$tripId/seats');
    final available = seatsResponse.data!
        .cast<Map<String, dynamic>>()
        .where((seat) => seat['status'] == 'AVAILABLE')
        .toList()
      ..sort((a, b) => int.parse(a['seat_number'] as String).compareTo(int.parse(b['seat_number'] as String)));

    if (available.length < 3) {
      throw StateError('Trip $tripId needs at least 3 available seats for this test to set itself up.');
    }

    final toReserve = available[0];
    final firstPick = available[1];
    final secondPick = available[2];

    reservedSeatNumber = toReserve['seat_number'] as String;
    firstPickSeatNumber = firstPick['seat_number'] as String;
    secondPickSeatNumber = secondPick['seat_number'] as String;
    firstPickPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(firstPick['seat_type'] as String)));
    secondPickPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(secondPick['seat_type'] as String)));

    final passengerSuffix = DateTime.now().millisecondsSinceEpoch;
    final registerResponse = await setupDio.post<Map<String, dynamic>>('/auth/register', data: {
      'first_name': 'Seat',
      'last_name': 'Fixture',
      'email': 'seat_fixture_$passengerSuffix@test.com',
      'phone': '+224699000088',
      'password': 'TestPass123!',
      'city': 'Conakry',
      'country_code': 'GN',
    });
    final fixtureToken = registerResponse.data!['access_token'] as String;

    await setupDio.post<Map<String, dynamic>>(
      '/trips/$tripId/bookings',
      data: {'seat_id': toReserve['seat_id']},
      options: Options(headers: {'Authorization': 'Bearer $fixtureToken'}),
    );
  });

  tearDownAll(() async {
    // Best-effort - this run's own dedicated fixture shouldn't become
    // tomorrow's orphaned route the way transport_company_management_
    // test.dart's does.
    try {
      await setupDio.delete<void>('/trips/$tripId', options: ownerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/routes/$routeId', options: ownerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/companies/$companyId', options: ownerAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('trip detail shows bus/driver info and a seat map with a real reserved seat', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp(tripId));
      // getTripDetail alone is ~8 sequential real requests (route,
      // company, bus, driver, both stations, both cities). Generous
      // margin since `flutter test` runs test files concurrently and
      // this local backend gets noticeably slower under that load.
      await Future.delayed(const Duration(seconds: 12));
      // The seat map section only mounts - and only then starts its
      // own GET .../seats fetch - once tripDetailProvider resolves and
      // the tree rebuilds past the loading state. Pump here, still
      // inside runAsync, so that fetch is created in the real zone
      // too, then give it its own real time to complete.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    // Route + company.
    expect(find.text(companyName), findsOneWidget);
    expect(find.text('Conakry'), findsOneWidget);
    expect(find.text('Kankan'), findsOneWidget);

    // Bus + driver.
    expect(find.textContaining('Mercedes-Benz Sprinter'), findsOneWidget);
    expect(find.textContaining('Ibrahima Camara'), findsOneWidget);
    expect(find.text('Climatisation'), findsOneWidget);

    // All 30 seats rendered.
    expect(find.text('30'), findsOneWidget);

    // The seat map sits below the fold on the default test viewport -
    // scroll each seat into view before tapping it.
    await tester.ensureVisible(find.text(reservedSeatNumber));
    await tester.pumpAndSettle();

    // Tapping the just-reserved seat does nothing - bottom bar stays empty.
    await tester.tap(find.text(reservedSeatNumber));
    await tester.pumpAndSettle();
    expect(find.text('Aucun siège sélectionné'), findsOneWidget);

    // Tapping an available seat selects it and shows its real price.
    await tester.ensureVisible(find.text(firstPickSeatNumber));
    await tester.pumpAndSettle();
    await tester.tap(find.text(firstPickSeatNumber));
    await tester.pumpAndSettle();
    expect(find.text('Siège $firstPickSeatNumber'), findsOneWidget);
    expect(find.text(firstPickPriceText), findsOneWidget);

    // Switching to a different seat updates the selection and price.
    await tester.ensureVisible(find.text(secondPickSeatNumber));
    await tester.pumpAndSettle();
    await tester.tap(find.text(secondPickSeatNumber));
    await tester.pumpAndSettle();
    expect(find.text('Siège $secondPickSeatNumber'), findsOneWidget);
    expect(find.text(secondPickPriceText), findsOneWidget);

    expect(find.widgetWithText(ElevatedButton, 'Continuer'), findsOneWidget);
  });
}

SeatType _seatTypeOf(String raw) {
  switch (raw) {
    case 'WINDOW':
      return SeatType.window;
    case 'AISLE':
      return SeatType.aisle;
    default:
      return SeatType.standard;
  }
}
