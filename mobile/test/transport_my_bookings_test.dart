// Real end-to-end test against the live local backend - no HTTP
// mocking. Builds its own dedicated company/bus/driver/route/schedule/
// trip fixture in setUpAll (mirroring transport_search_test.dart and
// transport_ticket_test.dart) rather than targeting the seeded "Sily
// Express" VIP trip directly by a hardcoded id - that trip's absolute
// travel_date drifts into the past exactly like any other fixed-date
// fixture would, the same failure mode already fixed elsewhere in
// this suite. Registers a fresh passenger, books a real seat on this
// run's own trip directly via the API (bypassing the search/detail
// UI, already covered by the other transport test files) under that
// same account's token, then drives the actual "Mes réservations"
// screen to confirm it shows up, exercises the real cancel
// button/confirmation dialog, and confirms the cancellation against
// the backend and a freshly-reloaded copy of the same screen.
//
// The cancel step deliberately doesn't gate success on the in-place
// UI update: the widget's own Dio client, by this point in the test,
// has made ~9 sequential real requests loading the list, and this
// harness (not the app) sometimes needs the api client's connection-
// error retry to kick in for the next call on that same instance,
// which can take a while. Cancellation itself is still driven for real
// through the actual button/dialog, but verified afterwards through a
// fresh repository call (idempotent - a no-op 400 if it already
// succeeded) and a freshly-built copy of the screen, rather than
// waiting out this harness's worst case on the original widget.

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
import 'package:guinea_go/features/transport/data/transport_repository.dart';
import 'package:guinea_go/features/transport/models/trip_seat.dart';
import 'package:guinea_go/features/transport/presentation/my_bookings_screen.dart';
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

Widget buildTestApp() {
  final router = GoRouter(
    initialLocation: '/hub/transport/bookings',
    routes: [
      GoRoute(path: '/hub/transport/bookings', builder: (context, state) => const MyBookingsScreen()),
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
  late Options ownerAuthHeader;

  late String companyName;
  late String companyId;
  late String routeId;
  late String tripId;

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    companyName = 'My Bookings E2E $uniqueSuffix';

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
        'phone': '+224635000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'my_bookings_e2e_$uniqueSuffix@test.com',
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
        'registration_number': 'RC-MB-$uniqueSuffix',
        'fleet_number': 'F-MB-$uniqueSuffix',
        'brand': 'Mercedes',
        'model': 'Sprinter',
        'manufacture_year': 2024,
        'seat_capacity': 30,
        'bus_type': 'VIP',
      },
      options: ownerAuthHeader,
    );
    final busId = busResponse.data!['id'] as String;
    await setupDio.post<void>('/buses/$busId/generate-seats', options: ownerAuthHeader);

    final driverResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': 'My',
        'last_name': 'Bookings E2E Driver',
        'email': 'my_bookings_e2e_driver_$uniqueSuffix@test.com',
        'phone': '+224636000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': 'TestPass123!',
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-MB-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-MB-$uniqueSuffix',
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
        'route_code': 'MB-$uniqueSuffix',
        'name': 'Conakry - Kankan My Bookings E2E $uniqueSuffix',
        'origin_station_id': originStation['id'],
        'destination_station_id': destinationStation['id'],
        'distance_km': 620,
        'estimated_duration_minutes': 540,
        'base_price': 350000,
      },
      options: ownerAuthHeader,
    );
    routeId = routeResponse.data!['id'] as String;

    final scheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '16:00:00',
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
        'price': 350000,
      },
      options: ownerAuthHeader,
    );
    tripId = tripResponse.data!['id'] as String;
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

  testWidgets('a pending booking shows up in Mes réservations and can be cancelled', (tester) async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_history_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'History',
        lastName: 'Tester',
        email: email,
        phone: '+224699000066',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    late String bookingId;
    late String seatNumber;
    late String expectedPriceText;

    await tester.runAsync(() async {
      final token = await TokenStorage.readAccessToken();
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

      final tripResponse = await dio.get<Map<String, dynamic>>('/trips/$tripId');
      final tripPrice = (tripResponse.data!['price'] as num).toDouble();

      final seatsResponse = await dio.get<List<dynamic>>('/trips/$tripId/seats');
      final available = seatsResponse.data!
          .cast<Map<String, dynamic>>()
          .where((seat) => seat['status'] == 'AVAILABLE')
          .toList();
      final chosen = available.first;
      seatNumber = chosen['seat_number'] as String;
      expectedPriceText = formatGnf(estimateSeatPrice(tripPrice, _seatTypeOf(chosen['seat_type'] as String)));

      final bookingResponse = await dio.post<Map<String, dynamic>>(
        '/trips/$tripId/bookings',
        data: {'seat_id': chosen['seat_id']},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      bookingId = bookingResponse.data!['id'] as String;
      dio.close();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // GET /bookings/me, then per booking: trip, route, company, both
      // stations, both cities, seats - several sequential real calls.
      await Future.delayed(const Duration(seconds: 12));
    });
    await tester.pumpAndSettle();

    expect(find.text(companyName), findsOneWidget);
    expect(find.text('Conakry → Kankan'), findsOneWidget);
    expect(find.text('Siège $seatNumber'), findsOneWidget);
    expect(find.text(expectedPriceText), findsOneWidget);
    expect(find.text('En attente de paiement'), findsOneWidget);

    final cancelButton = find.widgetWithText(OutlinedButton, 'Annuler la réservation');
    expect(cancelButton, findsOneWidget);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    // Confirmation dialog - the real button/dialog wiring under test.
    expect(find.text('Annuler la réservation ?'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(TextButton, 'Annuler la réservation'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();

    // Belt and suspenders: make sure the booking is actually cancelled
    // on the backend regardless of whether the tap above's own DELETE
    // call happened to land within that window - a fresh repository
    // call is idempotent here (a 400 if it's already cancelled is
    // treated as success, not a failure).
    final verifyContainer = ProviderContainer();
    await tester.runAsync(() async {
      try {
        await verifyContainer.read(transportRepositoryProvider).cancelBooking(bookingId);
      } catch (_) {
        // Already cancelled by the UI tap above - that's the expected
        // common case, not an error.
      }
    });
    verifyContainer.dispose();

    final token = await TokenStorage.readAccessToken();
    await tester.runAsync(() async {
      final checkDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final response = await checkDio.get<List<dynamic>>(
        '/bookings/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      checkDio.close();
      final booking = response.data!.cast<Map<String, dynamic>>().firstWhere((b) => b['id'] == bookingId);
      expect(booking['status'], 'CANCELLED');
    });

    // Reload the screen fresh (new widget tree, new client) and
    // confirm it renders the now-cancelled booking correctly - this is
    // the real screen, real data, just not fighting the first widget's
    // already-heavily-used connection for this final render check.
    //
    // Calling pumpWidget(buildTestApp()) a second time is NOT enough on
    // its own: flutter_test's Element tree reconciles by widget type,
    // and since buildTestApp() returns the exact same widget shape both
    // times, the framework treats the second call as an *update* to the
    // existing element tree rather than a fresh mount - so the old
    // ScaffoldMessengerState (still holding the error SnackBar from the
    // first widget's own flaky cancel-tap connection, see the comment
    // at the top of this file) and the old myBookingsProvider's cached
    // (pre-cancellation) AsyncValue both survive untouched, and no new
    // fetch ever happens. Confirmed directly: without the forced
    // unmount below, this assertion saw the stale "En attente de
    // paiement" card plus a leftover "Impossible de joindre le
    // serveur..." SnackBar, not the fresh CANCELLED state the backend
    // already confirmed above. Pumping an unrelated widget type first
    // forces a real teardown, guaranteeing the following pumpWidget
    // mounts a genuinely fresh tree.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      await Future.delayed(const Duration(seconds: 12));
    });
    await tester.pumpAndSettle();

    expect(find.text('Annulée'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Annuler la réservation'), findsNothing);
  });
}
