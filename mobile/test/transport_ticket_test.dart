// Real end-to-end test against the live local backend - no HTTP
// mocking. Books a real seat, pays via the sandbox endpoint, waits for
// the real booking_confirmed -> ticket-issued transition, then drives
// the actual "Voir le ticket" button from Mes réservations to the real
// TicketScreen and confirms it renders a QR code for the same code the
// backend issued.
//
// Builds its own dedicated company/bus/driver/route/schedule/trip
// fixture in setUpAll (mirroring transport_search_test.dart) rather
// than a hardcoded shared tripId. This used to target the seeded
// "Sily Express" trip 6a570f26ec6ed828b1a425d5 - the same trip
// transport_trip_detail_test.dart independently reserves a seat on for
// its own "real reserved seat" assertion. Sharing a trip across two
// test files racing concurrently is what actually broke this test: it
// snapshots "the first available seat" once in setUpAll, but
// trip_detail_test.dart's own concurrent run could reserve that exact
// seat moments later - the live SeatMap then renders it non-tappable
// (SeatBox's onTap is null for a non-AVAILABLE seat), so the widget's
// tap silently no-ops and "Siège N" never appears. Confirmed directly:
// this failure persisted across viewport-size and concurrency-level
// changes, which a genuine timing/rendering issue wouldn't explain but
// a stolen seat would. A dedicated trip removes the shared mutable
// state entirely, and dates it "today" fresh every run as a bonus
// (no more drifting into the past the way an absolute-dated seeded
// fixture would).
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

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options authHeader;

  late String companyId;
  late String routeId;
  late String tripId;
  late String seatNumber;
  late String expectedPriceText;

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final companyName = 'Ticket E2E $uniqueSuffix';

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
        'phone': '+224627000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'ticket_e2e_$uniqueSuffix@test.com',
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
        'registration_number': 'RC-TE-$uniqueSuffix',
        'fleet_number': 'F-TE-$uniqueSuffix',
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
        'first_name': 'Ticket',
        'last_name': 'E2E Driver',
        'email': 'ticket_e2e_driver_$uniqueSuffix@test.com',
        'phone': '+224628000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': 'TestPass123!',
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-TE-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-TE-$uniqueSuffix',
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
        'route_code': 'TE-$uniqueSuffix',
        'name': 'Conakry - Kankan Ticket E2E $uniqueSuffix',
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
        'departure_time': '09:00:00',
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
      await tester.pumpWidget(buildTestApp(tripId));
      // Generous margin under concurrent test-file load: this whole
      // suite now runs several real-backend-hitting files in parallel
      // (hotels, company management, ...), and this wait covers both
      // getTripDetail's own ~8 sequential calls and general contention
      // for the shared local backend/CPU.
      await Future.delayed(const Duration(seconds: 16));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 8));
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
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    expect(find.text('Récapitulatif'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la réservation'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 8));
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
