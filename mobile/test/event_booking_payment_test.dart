// Real end-to-end test against the live local backend - no HTTP
// mocking, no payment mocking. Uses the seeded event_organizer_e2e_
// fixture account (bootstrapped once via a direct Mongo role flip,
// same as hotel_owner_e2e_fixture/company_owner_e2e_fixture) to create
// a brand-new event and a ticket type with only 2 tickets total for
// every run - a fresh event/ticket type means this test never collides
// with a booking a previous run left behind, and the tiny quantity
// lets a single passenger legitimately buy every remaining ticket to
// exercise the "sold out" path without needing a second passenger.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/models/city.dart';
import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/core/utils/currency.dart';
import 'package:guinea_go/features/events/models/event_booking_selection.dart';
import 'package:guinea_go/features/events/models/event_search_params.dart';
import 'package:guinea_go/features/events/presentation/event_booking_screen.dart';
import 'package:guinea_go/features/events/presentation/event_detail_screen.dart';
import 'package:guinea_go/features/events/presentation/event_results_screen.dart';
import 'package:guinea_go/features/events/presentation/event_search_screen.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';

const _organizerEmail = 'event_organizer_e2e_fixture@test.com';
const _organizerPassword = 'TestPass123!';

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

Widget buildTestApp({String initialLocation = '/hub/events'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/hub/events',
        builder: (context, state) => const EventSearchScreen(),
        routes: [
          GoRoute(
            path: 'results',
            builder: (context, state) => EventResultsScreen(params: state.extra as EventSearchParams),
          ),
          GoRoute(
            path: ':eventId',
            builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['eventId']!),
            routes: [
              GoRoute(
                path: 'booking',
                builder: (context, state) =>
                    EventBookingScreen(selection: state.extra as EventBookingSelection),
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
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _selectDropdownItem(WidgetTester tester, Finder dropdownFinder, String itemText) async {
  await tester.ensureVisible(dropdownFinder);
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

String _isoDatetime(DateTime dateTime) => dateTime.toIso8601String();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options organizerAuthHeader;
  late String eventId;
  late String ticketTypeId;
  late String eventName;
  late double basePrice;
  late String expectedTotalText;

  setUpAll(() async {
    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _organizerEmail, 'password': _organizerPassword},
    );
    final organizerToken = loginResponse.data!['access_token'] as String;
    organizerAuthHeader = Options(headers: {'Authorization': 'Bearer $organizerToken'});

    final countriesResponse = await setupDio.get<List<dynamic>>('/countries/');
    final guinea = countriesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['code'] == 'GN');

    final citiesResponse = await setupDio.get<List<dynamic>>('/cities/', queryParameters: {'limit': 100});
    final conakryCity = citiesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Conakry');

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    eventName = 'Concert E2E $uniqueSuffix';
    final start = DateTime.now().add(const Duration(days: 14));
    final end = start.add(const Duration(hours: 3));

    final eventResponse = await setupDio.post<Map<String, dynamic>>(
      '/events/',
      data: {
        'name': eventName,
        'venue': 'Stade du 28 Septembre',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'start_datetime': _isoDatetime(start),
        'end_datetime': _isoDatetime(end),
        'category': 'CONCERT',
      },
      options: organizerAuthHeader,
    );
    eventId = eventResponse.data!['id'] as String;

    // Priced uniquely per run - not load-bearing here (this event is
    // dedicated, not shared), just consistent with the other E2E tests'
    // convention.
    basePrice = (50000 + (uniqueSuffix % 50000)).toDouble();

    final ticketTypeResponse = await setupDio.post<Map<String, dynamic>>(
      '/ticket-types/',
      data: {
        'event_id': eventId,
        'category': 'STANDARD',
        'base_price': basePrice,
        // Deliberately tiny: this run's passenger buys both, so the
        // "sold out" / no-oversell path is reachable within one test
        // without needing a second buyer.
        'quantity_total': 2,
      },
      options: organizerAuthHeader,
    );
    ticketTypeId = ticketTypeResponse.data!['id'] as String;

    expectedTotalText = formatGnf(basePrice * 2);
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/ticket-types/$ticketTypeId', options: organizerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/events/$eventId', options: organizerAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('search an event, buy every remaining ticket, pay, and confirm no overselling', (tester) async {
    // Same real-phone-width technique as the other E2E tests, doubling
    // as overflow-regression coverage for these screens too.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_event_booking_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'EventBooking',
        lastName: 'Tester',
        email: email,
        phone: '+224699000100',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // GET /cities/.
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<City>), 'Conakry');

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechercher'));
      await tester.pump();
      // searchEvents: GET /events/?city_id=, then per event GET
      // /ticket-types/... + GET /reviews/... - generous margin under
      // concurrent test-file load.
      await Future.delayed(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();

    expect(find.text(eventName), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text(eventName));
      await tester.pump();
      // GET /events/{id} - the ticket types list and review summary
      // widgets only mount (and start their own fetches) once this
      // resolves and the screen rebuilds, so pump again before waiting.
      await Future.delayed(const Duration(seconds: 4));
      await tester.pump();
      // GET /ticket-types/?event_id=... + GET /reviews/....
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('2 restant(s)'), findsOneWidget);

    // Bump quantity from the default 1 up to the max (2, the whole
    // remaining stock) via the stepper.
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();

    final reserveButton = find.widgetWithText(ElevatedButton, 'Réserver · $expectedTotalText');
    expect(reserveButton, findsOneWidget);
    // The "+" should now be disabled - already at max quantity.
    final incrementButton = find.ancestor(
      of: find.byIcon(Icons.add_circle_outline_rounded),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(incrementButton).onPressed, isNull);

    await tester.ensureVisible(reserveButton);
    await tester.tap(reserveButton);
    await tester.pumpAndSettle();

    expect(find.text('Récapitulatif'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text(expectedTotalText), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la réservation'));
      await tester.pump();
      // Real POST /ticket-types/{id}/bookings round trip.
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Réservation en attente de paiement'), findsOneWidget);
    expect(find.text(expectedTotalText), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer maintenant'));
      await tester.pump();
      // POST /event-bookings/{id}/payments (immediate "pending"
      // response), then the backend's own ~2s background task, then
      // this screen's single confirmation wait/lookup.
      await Future.delayed(const Duration(seconds: 18));
    });
    await tester.pumpAndSettle();

    expect(find.text('Réservation confirmée !'), findsOneWidget);
    expect(find.text(expectedTotalText), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);

    // No overselling, verified two ways:
    //
    // 1. Directly against the backend - the exact mechanism under test
    //    (claim_tickets' atomic compare-and-decrement) rejects a further
    //    purchase attempt with 409, independent of anything the UI does.
    await tester.runAsync(() async {
      final rejection = await setupDio
          .post<Map<String, dynamic>>(
            '/ticket-types/$ticketTypeId/bookings',
            data: {'quantity': 1},
            options: Options(headers: {'Authorization': 'Bearer $storedToken'}),
          )
          .then<DioException?>((_) => null)
          .catchError((error) => error as DioException);
      expect(rejection, isNotNull);
      expect(rejection!.response?.statusCode, 409);
    });

    // 2. From the UI itself - reloading the event detail screen shows
    //    the ticket type as sold out, with no quantity stepper or
    //    "Réserver" button offered at all, so there's no path to
    //    overselling through the app even if the backend check above
    //    didn't exist. Forces a full unmount before remounting at the
    //    detail route directly - pumpWidget() reconciles by widget
    //    type, so a second call with the same shape would otherwise
    //    reuse stale Element/provider state instead of doing a fresh
    //    fetch (see transport_my_bookings_test.dart's own fix for the
    //    same flutter_test behavior).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp(initialLocation: '/hub/events/$eventId'));
      await Future.delayed(const Duration(seconds: 4));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('Complet'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    expect(find.textContaining('Réserver ·'), findsNothing);
  });
}
