// Real end-to-end test against the live local backend - no HTTP
// mocking. Targets the seeded "Sily Express" morning trip (Conakry ->
// Kankan, 07:30, standard bus, 30 seats) directly by id.
//
// The reserved-seat fixture is created fresh in setUpAll (a real
// booking via a throwaway account) rather than relying on a seat
// reserved once by hand outside the test - a PENDING_PAYMENT booking
// expires after BOOKING_PAYMENT_TIMEOUT_MINUTES (10 min by default),
// so a fixture created once and left in the database would silently
// stop being reserved the next time this suite happens to run.
// Likewise the "available" seats used for selection are discovered at
// runtime rather than hardcoded, since a previous run of this same
// test already consumed whichever seat it reserved that time.

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

const _tripId = '6a570f26ec6ed828b1a425d5';

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

Widget buildTestApp() {
  final router = GoRouter(
    initialLocation: '/hub/transport/trips/$_tripId',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  late double tripPrice;
  late String reservedSeatNumber;
  late String firstPickSeatNumber;
  late String firstPickPriceText;
  late String secondPickSeatNumber;
  late String secondPickPriceText;

  setUpAll(() async {
    final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

    final tripResponse = await setupDio.get<Map<String, dynamic>>('/trips/$_tripId');
    tripPrice = (tripResponse.data!['price'] as num).toDouble();

    final seatsResponse = await setupDio.get<List<dynamic>>('/trips/$_tripId/seats');
    final available = seatsResponse.data!
        .cast<Map<String, dynamic>>()
        .where((seat) => seat['status'] == 'AVAILABLE')
        .toList()
      ..sort((a, b) => int.parse(a['seat_number'] as String).compareTo(int.parse(b['seat_number'] as String)));

    if (available.length < 3) {
      throw StateError('Trip $_tripId needs at least 3 available seats for this test to set itself up.');
    }

    final toReserve = available[0];
    final firstPick = available[1];
    final secondPick = available[2];

    reservedSeatNumber = toReserve['seat_number'] as String;
    firstPickSeatNumber = firstPick['seat_number'] as String;
    secondPickSeatNumber = secondPick['seat_number'] as String;
    firstPickPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(firstPick['seat_type'] as String)));
    secondPickPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(secondPick['seat_type'] as String)));

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final registerResponse = await setupDio.post<Map<String, dynamic>>('/auth/register', data: {
      'first_name': 'Seat',
      'last_name': 'Fixture',
      'email': 'seat_fixture_$uniqueSuffix@test.com',
      'phone': '+224699000088',
      'password': 'TestPass123!',
      'city': 'Conakry',
      'country_code': 'GN',
    });
    final fixtureToken = registerResponse.data!['access_token'] as String;

    await setupDio.post<Map<String, dynamic>>(
      '/trips/$_tripId/bookings',
      data: {'seat_id': toReserve['seat_id']},
      options: Options(headers: {'Authorization': 'Bearer $fixtureToken'}),
    );
  });

  testWidgets('trip detail shows bus/driver info and a seat map with a real reserved seat', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
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
    expect(find.text('Sily Express'), findsOneWidget);
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
