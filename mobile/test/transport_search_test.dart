// Real end-to-end test against the live local backend - no HTTP
// mocking, same pattern as auth_flow_test.dart.
//
// Does NOT depend on the originally-seeded "Sily Express" fixture
// trips (those are pinned to an absolute travel_date from whenever
// they were created, which drifts into the past exactly like any
// other fixed-date fixture would) nor on being the only route between
// Conakry and Kankan (transport_company_management_test.dart's own
// fixture runs leave orphaned routes/trips behind on that same city
// pair - company deletion doesn't cascade to them, see that file's own
// comments). Instead this test builds its own company/bus/driver/
// route/schedule/trip fixture fresh in setUpAll, dated "today" relative
// to whenever the test actually runs, under a company name unique to
// this run - so assertions are scoped to that unique company rather
// than a raw "N trajets" count that any other route sharing this city
// pair (past, present or future) could inflate.
//
// setUpAll builds the fixture directly via the API (fast, and this
// file's job is to test the search/results screens, not the company
// management forms already covered by transport_company_management_
// test.dart) using the pre-provisioned company_owner_e2e_fixture
// account. tearDownAll removes what it created, so repeated runs -
// including back-to-back runs of the whole suite - don't accumulate
// orphaned routes/trips of their own.
//
// Even the departure-time/price text is checked per-card (via the
// ancestor AppCard, not a bare find.text()) rather than asserting
// global uniqueness on the results page: other hardcoded-tripId
// fixtures elsewhere in this suite (e.g. transport_booking_payment_
// test.dart's "tomorrow, standard bus" trip) can independently drift
// onto today's date and happen to share a departure time with this
// run's own trips - confirmed happening with "07:30" while writing
// this fix. This test's own fixture is safe from that kind of drift
// (dated "today" fresh every run), but assertions still shouldn't
// assume it's the only thing on the page at that time.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/core/utils/currency.dart';
import 'package:guinea_go/core/widgets/app_card.dart';
import 'package:guinea_go/features/transport/models/trip_search_params.dart';
import 'package:guinea_go/features/transport/presentation/results_screen.dart';
import 'package:guinea_go/features/transport/presentation/search_screen.dart';

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
    initialLocation: '/hub/transport',
    routes: [
      GoRoute(
        path: '/hub/transport',
        builder: (context, state) => const SearchScreen(),
        routes: [
          GoRoute(
            path: 'results',
            builder: (context, state) => ResultsScreen(params: state.extra as TripSearchParams),
          ),
        ],
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
  late Options authHeader;

  late String companyName;
  late String companyId;
  late String routeId;
  final tripIds = <String>[];
  late String earlyPriceText;
  late String latePriceText;

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    companyName = 'Search E2E $uniqueSuffix';

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
        'phone': '+224625000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'search_e2e_$uniqueSuffix@test.com',
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
        'registration_number': 'RC-SE-$uniqueSuffix',
        'fleet_number': 'F-SE-$uniqueSuffix',
        'brand': 'Mercedes',
        'model': 'Sprinter',
        'manufacture_year': 2024,
        'seat_capacity': 30,
        'bus_type': 'STANDARD',
      },
      options: authHeader,
    );
    final busId = busResponse.data!['id'] as String;

    final driverResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': 'Search',
        'last_name': 'E2E Driver',
        'email': 'search_e2e_driver_$uniqueSuffix@test.com',
        'phone': '+224626000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': 'TestPass123!',
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-SE-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-SE-$uniqueSuffix',
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
        'route_code': 'SE-$uniqueSuffix',
        'name': 'Conakry - Kankan Search E2E $uniqueSuffix',
        'origin_station_id': originStation['id'],
        'destination_station_id': destinationStation['id'],
        'distance_km': 620,
        'estimated_duration_minutes': 540,
        'base_price': 250000,
      },
      options: authHeader,
    );
    routeId = routeResponse.data!['id'] as String;

    const allDays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];

    final earlyScheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '07:30:00',
        'operating_days': allDays,
      },
      options: authHeader,
    );
    final lateScheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '14:00:00',
        'operating_days': allDays,
      },
      options: authHeader,
    );

    final today = _isoDate(DateTime.now());
    const earlyPrice = 250000.0;
    const latePrice = 320000.0;
    earlyPriceText = formatGnf(earlyPrice);
    latePriceText = formatGnf(latePrice);

    final earlyTripResponse = await setupDio.post<Map<String, dynamic>>(
      '/trips/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'schedule_id': earlyScheduleResponse.data!['id'],
        'bus_id': busId,
        'driver_id': driverId,
        'travel_date': today,
        'price': earlyPrice,
      },
      options: authHeader,
    );
    tripIds.add(earlyTripResponse.data!['id'] as String);
    final lateTripResponse = await setupDio.post<Map<String, dynamic>>(
      '/trips/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'schedule_id': lateScheduleResponse.data!['id'],
        'bus_id': busId,
        'driver_id': driverId,
        'travel_date': today,
        'price': latePrice,
      },
      options: authHeader,
    );
    tripIds.add(lateTripResponse.data!['id'] as String);
  });

  tearDownAll(() async {
    // Best-effort - this run's own fixture shouldn't become tomorrow's
    // orphaned route the way transport_company_management_test.dart's
    // does, so trips/route/company created above are cleaned up
    // regardless of how the test itself fared.
    for (final tripId in tripIds) {
      try {
        await setupDio.delete<void>('/trips/$tripId', options: authHeader);
      } catch (_) {}
    }
    try {
      await setupDio.delete<void>('/routes/$routeId', options: authHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/companies/$companyId', options: authHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('search Conakry -> Kankan today finds this run\'s own trips, sortable', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    // Origin dropdown.
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<Object?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conakry').last);
    await tester.pumpAndSettle();

    // Destination dropdown.
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<Object?>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kankan').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechercher'));
      // ResultsScreen (and the ref.watch that starts the real fetch)
      // doesn't mount until the next frame - pump once, still inside
      // runAsync, so that fetch is created in the real zone rather
      // than only appearing once pumpAndSettle's fake-clock pumping
      // gets to it.
      await tester.pump();
      // The search fans out into several sequential real requests
      // (stations x2, routes, trips per matching route, company) -
      // needs more real time than a single round trip, and more so
      // given however many other routes now exist on this city pair.
      await Future.delayed(const Duration(seconds: 12));
    });
    await tester.pumpAndSettle();

    expect(find.text('Conakry → Kankan'), findsOneWidget);

    // Scoped to this run's uniquely-named company rather than the
    // total trip count or bare time/price text - other routes sharing
    // this city pair (leaked fixtures from other test files, or
    // genuinely new trips created by a second back-to-back run of this
    // same test) are expected and tolerated, not treated as failures,
    // and can coincidentally share a departure time or price with this
    // run's own trips (see the file header comment).
    final companyCards = find.ancestor(of: find.text(companyName), matching: find.byType(AppCard));
    expect(companyCards, findsNWidgets(2));

    bool cardHasText(int index, String text) =>
        find.descendant(of: companyCards.at(index), matching: find.text(text)).evaluate().isNotEmpty;

    final earlyCardIndex = cardHasText(0, '07:30') ? 0 : 1;
    final lateCardIndex = 1 - earlyCardIndex;

    expect(cardHasText(earlyCardIndex, '07:30'), isTrue);
    expect(cardHasText(earlyCardIndex, earlyPriceText), isTrue);
    expect(cardHasText(lateCardIndex, '14:00'), isTrue);
    expect(cardHasText(lateCardIndex, latePriceText), isTrue);

    // Sort chips are tappable and don't drop this run's own trips.
    await tester.tap(find.text('Prix'));
    await tester.pumpAndSettle();
    expect(find.text(companyName), findsNWidgets(2));
  });
}
