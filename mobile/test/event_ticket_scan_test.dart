// Real end-to-end test against the live local backend - no HTTP
// mocking, no payment mocking. Uses the seeded event_organizer_e2e_
// fixture account (bootstrapped once via a direct Mongo role flip,
// same as hotel_owner_e2e_fixture) to create a dedicated event/ticket
// type per run, and event_organizer_other_e2e_fixture (a second,
// permanently-role-flipped organizer account, same bootstrap) to
// exercise the "wrong organizer" rejection.
//
// Drives the real passenger flow all the way to the QR ticket screen -
// that part is fully UI-testable. Validation itself is exercised
// through the real EventOrganizerRepository.validateTicket() call
// (the same one EventTicketScanScreen's _onDetect makes) rather than
// through the scan screen's camera widget: MobileScanner needs actual
// camera hardware/platform channels that don't exist in flutter test's
// headless environment (confirmed directly - even just mounting
// EventTicketScanScreen throws MissingPluginException, since
// MobileScannerController.start() runs in initState), and there is no
// public way to inject a fake barcode detection into it either. No
// test in this suite drives TicketScanScreen (transport's equivalent)
// through a simulated scan or even mounts it, for the same reason -
// this is a genuine platform testing limitation, not something skipped
// for convenience.

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
import 'package:guinea_go/features/events/data/event_organizer_repository.dart';
import 'package:guinea_go/features/events/models/event_booking_selection.dart';
import 'package:guinea_go/features/events/models/event_booking_summary.dart';
import 'package:guinea_go/features/events/models/event_search_params.dart';
import 'package:guinea_go/features/events/presentation/event_booking_screen.dart';
import 'package:guinea_go/features/events/presentation/event_detail_screen.dart';
import 'package:guinea_go/features/events/presentation/event_results_screen.dart';
import 'package:guinea_go/features/events/presentation/event_search_screen.dart';
import 'package:guinea_go/features/events/presentation/event_ticket_scan_screen.dart';
import 'package:guinea_go/features/events/presentation/event_ticket_screen.dart';
import 'package:guinea_go/features/events/presentation/my_event_bookings_screen.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';

const _organizerEmail = 'event_organizer_e2e_fixture@test.com';
const _organizerPassword = 'TestPass123!';
const _otherOrganizerEmail = 'event_organizer_other_e2e_fixture@test.com';
const _otherOrganizerPassword = 'TestPass123!';

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
    initialLocation: '/hub/events',
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
            path: 'bookings',
            builder: (context, state) => const MyEventBookingsScreen(),
            routes: [
              GoRoute(
                path: 'ticket',
                builder: (context, state) => EventTicketScreen(summary: state.extra as EventBookingSummary),
              ),
            ],
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
      GoRoute(
        path: '/hub/organizer/scan',
        builder: (context, state) => const EventTicketScanScreen(),
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

String _formatGnf(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }

  return '${rounded < 0 ? '-' : ''}$buffer FG';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options organizerAuthHeader;
  late String eventId;
  late String ticketTypeId;
  late String eventName;
  const basePrice = 20000.0;

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
    eventName = 'Scan E2E $uniqueSuffix';
    final start = DateTime.now().add(const Duration(days: 21));
    final end = start.add(const Duration(hours: 3));

    final eventResponse = await setupDio.post<Map<String, dynamic>>(
      '/events/',
      data: {
        'name': eventName,
        'venue': 'Palais des Sports',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'start_datetime': _isoDatetime(start),
        'end_datetime': _isoDatetime(end),
        'category': 'CONCERT',
      },
      options: organizerAuthHeader,
    );
    eventId = eventResponse.data!['id'] as String;

    final ticketTypeResponse = await setupDio.post<Map<String, dynamic>>(
      '/ticket-types/',
      data: {
        'event_id': eventId,
        'category': 'STANDARD',
        'base_price': basePrice,
        // Room for the UI-driven booking plus a second, API-created one
        // for the wrong-organizer rejection check below.
        'quantity_total': 3,
      },
      options: organizerAuthHeader,
    );
    ticketTypeId = ticketTypeResponse.data!['id'] as String;
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

  testWidgets(
    'confirmed booking issues a QR ticket, the right organizer can validate it once, '
    'and neither reuse nor a different organizer are accepted',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final email = 'flutter_event_scan_$uniqueSuffix@test.com';

      final authContainer = ProviderContainer();
      await tester.runAsync(() async {
        await authContainer.read(authControllerProvider.notifier).register(
          firstName: 'EventScan',
          lastName: 'Tester',
          email: email,
          phone: '+224699000101',
          password: 'TestPass123!',
          city: 'Conakry',
        );
      });
      authContainer.dispose();

      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestApp());
        await Future.delayed(const Duration(seconds: 4));
      });
      await tester.pumpAndSettle();

      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<City>), 'Conakry');

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Rechercher'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 10));
      });
      await tester.pumpAndSettle();

      expect(find.text(eventName), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text(eventName));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
      });
      await tester.pumpAndSettle();

      final reserveButton = find.widgetWithText(ElevatedButton, 'Réserver · ${_formatGnf(basePrice)}');
      await tester.ensureVisible(reserveButton);
      await tester.tap(reserveButton);
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
        await Future.delayed(const Duration(seconds: 18));
      });
      await tester.pumpAndSettle();

      expect(find.text('Réservation confirmée !'), findsOneWidget);

      // The confirmed booking's real ticket code, resolved independently
      // of the UI, to compare against what the screen renders below -
      // same pattern as transport_ticket_test.dart.
      final token = await TokenStorage.readAccessToken();
      late String bookingId;
      late String expectedCode;
      await tester.runAsync(() async {
        final checkDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final bookingsResponse = await checkDio.get<List<dynamic>>(
          '/event-bookings/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final confirmed = bookingsResponse.data!
            .cast<Map<String, dynamic>>()
            .firstWhere((b) => b['status'] == 'CONFIRMED');
        bookingId = confirmed['id'] as String;

        final ticketResponse = await checkDio.get<Map<String, dynamic>>(
          '/event-bookings/$bookingId/ticket',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        expectedCode = ticketResponse.data!['code'] as String;
        expect(ticketResponse.data!['status'], 'VALID');
        checkDio.close();
      });

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Voir mes réservations'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 10));
      });
      await tester.pumpAndSettle();

      expect(find.text('Mes billets'), findsOneWidget);

      final ticketButton = find.widgetWithText(ElevatedButton, 'Voir le billet');
      await tester.ensureVisible(ticketButton);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(ticketButton);
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();

      expect(find.text('Mon billet'), findsOneWidget);
      expect(find.text(expectedCode), findsOneWidget);
      expect(find.text('Valide'), findsOneWidget);

      // Validation itself - see the file header comment for why this
      // goes through the repository rather than the scan screen's
      // camera widget.
      final organizerContainer = ProviderContainer();
      await tester.runAsync(() async {
        await organizerContainer.read(authControllerProvider.notifier).login(
          email: _organizerEmail,
          password: _organizerPassword,
        );
        final result = await organizerContainer
            .read(eventOrganizerRepositoryProvider)
            .validateTicket(expectedCode);
        expect(result.status.name, 'used');
        expect(result.passengerName, 'EventScan Tester');
        expect(result.ticketCategory, 'STANDARD');
      });

      // Reuse is rejected.
      await tester.runAsync(() async {
        Object? caught;
        try {
          await organizerContainer.read(eventOrganizerRepositoryProvider).validateTicket(expectedCode);
        } catch (error) {
          caught = error;
        }
        expect(caught, isNotNull);
        expect((caught as DioException).response?.statusCode, 400);
      });
      organizerContainer.dispose();

      // A second, separate booking (created directly against the API -
      // the UI-driven purchase above already exercised the real
      // booking flow once) gives a fresh VALID ticket to prove a
      // *different* organizer's event is rejected, independent of the
      // "already used" rejection just checked above.
      late String otherEventTicketCode;
      await tester.runAsync(() async {
        final secondBookingResponse = await setupDio.post<Map<String, dynamic>>(
          '/ticket-types/$ticketTypeId/bookings',
          data: {'quantity': 1},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final secondBookingId = secondBookingResponse.data!['id'] as String;
        await setupDio.post<Map<String, dynamic>>(
          '/event-bookings/$secondBookingId/payments',
          data: {'provider': 'orange_money', 'amount': basePrice},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        await Future.delayed(const Duration(seconds: 3));
        final secondTicketResponse = await setupDio.get<Map<String, dynamic>>(
          '/event-bookings/$secondBookingId/ticket',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        otherEventTicketCode = secondTicketResponse.data!['code'] as String;
      });

      final otherOrganizerContainer = ProviderContainer();
      await tester.runAsync(() async {
        await otherOrganizerContainer.read(authControllerProvider.notifier).login(
          email: _otherOrganizerEmail,
          password: _otherOrganizerPassword,
        );
        Object? caught;
        try {
          await otherOrganizerContainer
              .read(eventOrganizerRepositoryProvider)
              .validateTicket(otherEventTicketCode);
        } catch (error) {
          caught = error;
        }
        expect(caught, isNotNull);
        expect((caught as DioException).response?.statusCode, 403);
      });
      otherOrganizerContainer.dispose();
    },
  );
}
