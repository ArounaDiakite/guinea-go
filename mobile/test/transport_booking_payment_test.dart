// Real end-to-end test against the live local backend - no HTTP
// mocking, no payment mocking. Books a real booking, pays via the
// sandbox endpoint, and waits for the backend's real ~2s background
// task to flip the booking to CONFIRMED.
//
// Builds its own dedicated company/bus/driver/route/schedule/trip
// fixture in setUpAll (mirroring transport_search_test.dart and
// transport_ticket_test.dart) rather than depending on the seeded
// "Sily Express" tomorrow-morning trip. This test creates a real,
// permanent CONFIRMED booking each run with no teardown for the
// booking itself, so a shared/hardcoded trip eventually runs out of
// seats under the accumulated weight of every past run against it -
// confirmed happening after enough runs this session. A dedicated
// trip with its own freshly-generated seats removes that shared
// mutable state entirely, dated "today" fresh every run.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';
import 'package:guinea_go/features/transport/models/trip_seat.dart';
import 'package:guinea_go/features/transport/presentation/booking_screen.dart';
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
        routes: [
          GoRoute(
            path: 'booking',
            builder: (context, state) => BookingScreen(
              tripId: state.pathParameters['tripId']!,
              seat: state.extra as TripSeat,
            ),
            routes: [
              GoRoute(
                path: 'payment',
                builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
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

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options authHeader;

  late String companyName;
  late String companyId;
  late String routeId;
  late String tripId;
  late String seatNumber;
  late String expectedPriceText;

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    companyName = 'Booking Payment E2E $uniqueSuffix';

    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _ownerEmail, 'password': _ownerPassword},
    );
    final token = loginResponse.data!['access_token'] as String;
    authHeader = Options(headers: {'Authorization': 'Bearer $token'});

    final countriesResponse = await setupDio.get<List<dynamic>>('/countries/');
    final guinea = countriesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['code'] == 'GN');

    final citiesResponse = await setupDio.get<List<dynamic>>('/cities/', queryParameters: {'limit': 100});
    final conakryCity = citiesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Conakry');

    final companyResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/',
      data: {
        'name': companyName,
        'company_type': 'BUS',
        'phone': '+224629000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'booking_payment_e2e_$uniqueSuffix@test.com',
        'address': 'Kaloum, Conakry',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
      },
      options: authHeader,
    );
    companyId = companyResponse.data!['id'] as String;

    final busResponse = await setupDio.post<Map<String, dynamic>>(
      '/buses/',
      data: {
        'company_id': companyId,
        'registration_number': 'RC-BP-$uniqueSuffix',
        'fleet_number': 'F-BP-$uniqueSuffix',
        'brand': 'Mercedes',
        'model': 'Sprinter',
        'manufacture_year': 2024,
        'seat_capacity': 30,
        'bus_type': 'STANDARD',
      },
      options: authHeader,
    );
    final busId = busResponse.data!['id'] as String;
    await setupDio.post<void>('/buses/$busId/generate-seats', options: authHeader);

    final driverResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': 'Booking',
        'last_name': 'Payment E2E Driver',
        'email': 'booking_payment_e2e_driver_$uniqueSuffix@test.com',
        'phone': '+224630000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': 'TestPass123!',
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-BP-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-BP-$uniqueSuffix',
          'license_category': 'D',
          'license_expiry_date': _isoDate(DateTime.now().add(const Duration(days: 730))),
          'years_of_experience': 5,
        },
      },
      options: authHeader,
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
        'route_code': 'BP-$uniqueSuffix',
        'name': 'Conakry - Kankan Booking Payment E2E $uniqueSuffix',
        'origin_station_id': originStation['id'],
        'destination_station_id': destinationStation['id'],
        'distance_km': 620,
        'estimated_duration_minutes': 540,
        'base_price': 250000,
      },
      options: authHeader,
    );
    routeId = routeResponse.data!['id'] as String;

    final scheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '08:00:00',
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
      options: authHeader,
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
      options: authHeader,
    );
    tripId = tripResponse.data!['id'] as String;
    final tripPrice = (tripResponse.data!['price'] as num).toDouble();

    final seatsResponse = await setupDio.get<List<dynamic>>('/trips/$tripId/seats');
    final available = seatsResponse.data!
        .cast<Map<String, dynamic>>()
        .where((seat) => seat['status'] == 'AVAILABLE')
        .toList()
      ..sort((a, b) => int.parse(a['seat_number'] as String).compareTo(int.parse(b['seat_number'] as String)));

    if (available.isEmpty) {
      throw StateError('Trip $tripId has no available seats left for this test to book.');
    }

    final chosen = available.first;
    seatNumber = chosen['seat_number'] as String;
    expectedPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(chosen['seat_type'] as String)));
  });

  tearDownAll(() async {
    // Best-effort - this run's own dedicated fixture shouldn't become
    // tomorrow's orphaned route the way transport_company_management_
    // test.dart's does.
    try {
      await setupDio.delete<void>('/trips/$tripId', options: authHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/routes/$routeId', options: authHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/companies/$companyId', options: authHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('book a seat, pay via the sandbox, and see the booking confirmed', (tester) async {
    // POST /trips/{id}/bookings requires a logged-in user - log one in
    // for real first, the same way auth_flow_test.dart does, so the
    // token the api client attaches is a genuine one.
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_booking_$uniqueSuffix@test.com';

    // Register via the controller directly - no need to drive the
    // actual login UI in this test, only the resulting stored token
    // matters for the booking/payment calls that follow.
    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'Booking',
        lastName: 'Tester',
        email: email,
        phone: '+224699000077',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp(tripId));
      // getTripDetail (~8 sequential calls). Generous margin since
      // `flutter test` runs test files concurrently and this local
      // backend gets noticeably slower under that load.
      await Future.delayed(const Duration(seconds: 12));
      // Mount the seat map section and let its own fetch complete.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(seatNumber));
    await tester.pumpAndSettle();
    await tester.tap(find.text(seatNumber));
    await tester.pumpAndSettle();

    expect(find.text('Siège $seatNumber'), findsOneWidget);
    expect(find.text(expectedPriceText), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    // Booking recap screen.
    expect(find.text('Récapitulatif'), findsOneWidget);
    expect(find.text(companyName), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la réservation'));
      await tester.pump();
      // Real POST /trips/{id}/bookings round trip.
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    // Payment screen, still PENDING_PAYMENT.
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Réservation en attente de paiement'), findsOneWidget);
    expect(find.text(expectedPriceText), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer maintenant'));
      await tester.pump();
      // POST /bookings/{id}/payments (immediate "pending" response),
      // then the backend's own ~2s background task, then this
      // screen's poll interval (2s) picking up the CONFIRMED status -
      // give it comfortable real headroom, more so under concurrent
      // test-file load.
      await Future.delayed(const Duration(seconds: 18));
    });
    await tester.pumpAndSettle();

    expect(find.text('Réservation confirmée !'), findsOneWidget);
    expect(find.text(expectedPriceText), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
  });
}
