// Real end-to-end test against the live local backend - no HTTP
// mocking, no payment mocking. Targets the seeded "Sily Express"
// tomorrow-morning trip (Conakry -> Kankan, standard bus). Books a
// real booking, pays via the sandbox endpoint, and waits for the
// backend's real ~2s background task to flip the booking to CONFIRMED.
//
// The seat used is discovered at runtime (first currently-AVAILABLE
// seat on the trip) rather than hardcoded - this test creates a real,
// permanent CONFIRMED booking each time it runs, so a hardcoded seat
// number would only be bookable on the very first run and fail every
// run after that.

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
import 'package:guinea_go/features/transport/models/booking.dart';
import 'package:guinea_go/features/transport/models/trip_seat.dart';
import 'package:guinea_go/features/transport/presentation/booking_screen.dart';
import 'package:guinea_go/features/transport/presentation/payment_screen.dart';
import 'package:guinea_go/features/transport/presentation/trip_detail_screen.dart';
import 'package:guinea_go/features/transport/utils/currency.dart';
import 'package:guinea_go/features/transport/utils/seat_pricing.dart';

const _tripId = '6a570f26ec6ed828b1a425d7'; // tomorrow, standard bus

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
                builder: (context, state) => PaymentScreen(booking: state.extra as Booking),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  late String seatNumber;
  late String expectedPriceText;

  setUpAll(() async {
    final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

    final tripResponse = await setupDio.get<Map<String, dynamic>>('/trips/$_tripId');
    final tripPrice = (tripResponse.data!['price'] as num).toDouble();

    final seatsResponse = await setupDio.get<List<dynamic>>('/trips/$_tripId/seats');
    final available = seatsResponse.data!
        .cast<Map<String, dynamic>>()
        .where((seat) => seat['status'] == 'AVAILABLE')
        .toList()
      ..sort((a, b) => int.parse(a['seat_number'] as String).compareTo(int.parse(b['seat_number'] as String)));

    if (available.isEmpty) {
      throw StateError('Trip $_tripId has no available seats left for this test to book.');
    }

    final chosen = available.first;
    seatNumber = chosen['seat_number'] as String;
    expectedPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(chosen['seat_type'] as String)));
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
      await tester.pumpWidget(buildTestApp());
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
    expect(find.text('Sily Express'), findsOneWidget);

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
