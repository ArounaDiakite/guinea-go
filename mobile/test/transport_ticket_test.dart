// Real end-to-end test against the live local backend - no HTTP
// mocking. Books a real seat on the seeded "Sily Express" trip
// (Conakry -> Kankan, the same trip used by the GET /bookings/{id}
// smoke test), pays via the sandbox endpoint, waits for the real
// booking_confirmed -> ticket-issued transition, then drives the
// actual "Voir le ticket" button from Mes réservations to the real
// TicketScreen and confirms it renders a QR code for the same code
// the backend issued.
//
// Ticket validation itself (POST /tickets/{code}/validate) has no
// driver/company_owner UI yet - it's exercised manually against the
// live backend instead, since there's nothing to drive in the app for
// it at this stage (see the next module: driver screens).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';
import 'package:guinea_go/features/transport/models/booking_summary.dart';
import 'package:guinea_go/features/transport/models/trip_seat.dart';
import 'package:guinea_go/features/transport/presentation/booking_screen.dart';
import 'package:guinea_go/features/transport/presentation/my_bookings_screen.dart';
import 'package:guinea_go/features/transport/presentation/ticket_screen.dart';
import 'package:guinea_go/features/transport/presentation/trip_detail_screen.dart';
import 'package:guinea_go/core/utils/currency.dart';
import 'package:guinea_go/features/transport/utils/seat_pricing.dart';

const _tripId = '6a570f26ec6ed828b1a425d5'; // today, standard bus

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
                builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/hub/transport/bookings',
        builder: (context, state) => const MyBookingsScreen(),
        routes: [
          GoRoute(
            path: 'ticket',
            builder: (context, state) => TicketScreen(summary: state.extra as BookingSummary),
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

  testWidgets('a confirmed booking gets a ticket, shown as a QR code from Mes réservations', (tester) async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_ticket_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'Ticket',
        lastName: 'Tester',
        email: email,
        phone: '+224699000088',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      await Future.delayed(const Duration(seconds: 12));
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

    expect(find.text('Récapitulatif'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la réservation'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    expect(find.text('Paiement'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer maintenant'));
      await tester.pump();
      // POST /bookings/{id}/payments, then the backend's sandbox
      // completion (~2s) - which is also when the ticket gets issued -
      // then this screen's own single confirmation wait/lookup.
      await Future.delayed(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();

    expect(find.text('Réservation confirmée !'), findsOneWidget);

    // The confirmed booking's id, resolved independently of the UI, to
    // fetch the ticket the backend actually issued and compare it
    // against what the screen renders below.
    final token = await TokenStorage.readAccessToken();
    late String bookingId;
    late String expectedCode;
    await tester.runAsync(() async {
      final checkDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final bookingsResponse = await checkDio.get<List<dynamic>>(
        '/bookings/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final confirmed = bookingsResponse.data!
          .cast<Map<String, dynamic>>()
          .firstWhere((b) => b['status'] == 'CONFIRMED');
      bookingId = confirmed['id'] as String;

      final ticketResponse = await checkDio.get<Map<String, dynamic>>(
        '/bookings/$bookingId/ticket',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      expectedCode = ticketResponse.data!['code'] as String;
      expect(ticketResponse.data!['status'], 'VALID');
      checkDio.close();
    });

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Voir mes réservations'));
      await tester.pump();
      // GET /bookings/me, then per booking: trip, route, company, both
      // stations, both cities, seats.
      await Future.delayed(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();

    expect(find.text('Mes réservations'), findsOneWidget);

    final ticketButton = find.widgetWithText(ElevatedButton, 'Voir le ticket');
    await tester.ensureVisible(ticketButton);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(ticketButton);
      await tester.pump();
      // GET /bookings/{id}/ticket, driven by the real screen this time.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('Mon ticket'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(expectedCode), findsOneWidget);
    expect(find.text('Valide'), findsOneWidget);
  });
}
