// Real end-to-end test against the live local backend - no HTTP
// mocking, no payment mocking. Uses the seeded hotel_owner_e2e_fixture
// account (bootstrapped once via a direct Mongo role flip, same as
// company_owner_e2e_fixture/driver_e2e_fixture) to create a brand-new
// room on their existing "Hotel E2E Test" hotel for every run - a
// fresh room means this test never collides with a booking a previous
// run left behind, without needing to hardcode or discover available
// dates.

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
import 'package:guinea_go/features/hotels/models/hotel_booking_selection.dart';
import 'package:guinea_go/features/hotels/models/hotel_search_params.dart';
import 'package:guinea_go/features/hotels/models/hotel_stay.dart';
import 'package:guinea_go/features/hotels/presentation/hotel_booking_screen.dart';
import 'package:guinea_go/features/hotels/presentation/hotel_detail_screen.dart';
import 'package:guinea_go/features/hotels/presentation/hotel_results_screen.dart';
import 'package:guinea_go/features/hotels/presentation/hotel_search_screen.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';
import 'package:guinea_go/core/utils/currency.dart';

const _hotelOwnerEmail = 'hotel_owner_e2e_fixture@test.com';
const _hotelOwnerPassword = 'TestPass123!';

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
    initialLocation: '/hub/hotels',
    routes: [
      GoRoute(
        path: '/hub/hotels',
        builder: (context, state) => const HotelSearchScreen(),
        routes: [
          GoRoute(
            path: 'results',
            builder: (context, state) => HotelResultsScreen(params: state.extra as HotelSearchParams),
          ),
          GoRoute(
            path: ':hotelId',
            builder: (context, state) =>
                HotelDetailScreen(hotelId: state.pathParameters['hotelId']!, stay: state.extra as HotelStay),
            routes: [
              GoRoute(
                path: 'booking',
                builder: (context, state) => HotelBookingScreen(selection: state.extra as HotelBookingSelection),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  late String roomNumber;
  late double basePrice;
  late String expectedTotalText;

  setUpAll(() async {
    final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _hotelOwnerEmail, 'password': _hotelOwnerPassword},
    );
    final ownerToken = loginResponse.data!['access_token'] as String;
    final ownerId = (loginResponse.data!['user'] as Map<String, dynamic>)['id'] as String;

    final hotelsResponse = await setupDio.get<List<dynamic>>(
      '/hotels/',
      queryParameters: {'owner_id': ownerId, 'limit': 1},
      options: Options(headers: {'Authorization': 'Bearer $ownerToken'}),
    );
    if (hotelsResponse.data!.isEmpty) {
      throw StateError(
        'hotel_owner_e2e_fixture has no hotel yet - create one manually before running this test.',
      );
    }
    final hotel = hotelsResponse.data!.first as Map<String, dynamic>;
    final hotelId = hotel['id'] as String;

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    roomNumber = 'E2E-$uniqueSuffix';
    // Priced uniquely per run (not just numbered uniquely) - the "Réserver
    // · <price>" button label is otherwise indistinguishable from every
    // other room a previous run of this same test left behind on the
    // fixture hotel, which have all accumulated at the same fixed price.
    basePrice = (100000 + (uniqueSuffix % 100000)).toDouble();

    await setupDio.post<Map<String, dynamic>>(
      '/rooms/',
      data: {
        'hotel_id': hotelId,
        'room_number': roomNumber,
        'room_type': 'SIMPLE',
        'capacity': 1,
        'base_price': basePrice,
      },
      options: Options(headers: {'Authorization': 'Bearer $ownerToken'}),
    );

    // HotelSearchScreen defaults check_in/check_out to tomorrow -> the
    // day after, i.e. exactly one night - so the total equals the
    // per-night price here.
    expectedTotalText = formatGnf(basePrice * 1);
  });

  testWidgets('search a hotel, book a room, pay via the sandbox, and see it confirmed', (tester) async {
    // The default 800x600 test surface is short enough that a room
    // card sorted further down the list (this fixture hotel has
    // accumulated many rooms from past runs, each priced essentially
    // randomly) can get scrolled by ensureVisible() to sit right at
    // the bottom edge of the viewport - tap() then silently misses,
    // same failure mode root-caused in transport_ticket_test.dart's
    // seat grid. Only the height is extended (width kept at the
    // default 800) - some Row layouts on this screen and the results
    // screen overflow at a genuinely phone-narrow width since they
    // weren't built/tested against one; a real layout gap, but not
    // one this test should block on or paper over here.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_hotel_booking_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'HotelBooking',
        lastName: 'Tester',
        email: email,
        phone: '+224699000099',
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

    // Defaults to tomorrow -> the day after (see HotelSearchScreen) -
    // no need to touch the date pickers, and the freshly created room
    // above has no bookings yet for any date range.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechercher'));
      await tester.pump();
      // searchHotels: GET /hotels/?city_id=, then per hotel GET
      // /rooms/... + GET /reviews/... - generous margin under
      // concurrent test-file load.
      await Future.delayed(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();

    // "À partir de X" on this card is the minimum across every room
    // this fixture hotel has ever had across test runs (rooms from
    // past runs are never deleted), so it isn't necessarily this run's
    // room price - only the hotel's presence is asserted here; the
    // room this run created is checked specifically on the detail
    // screen below.
    expect(find.text('Hotel E2E Test'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Hotel E2E Test'));
      await tester.pump();
      // GET /hotels/{id} - the room list and review summary widgets
      // only mount (and start their own fetches) once this resolves
      // and the screen rebuilds, so pump again before waiting on them.
      await Future.delayed(const Duration(seconds: 4));
      await tester.pump();
      // GET /rooms/?hotel_id=... + GET /reviews/....
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Chambre $roomNumber'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Réserver · $expectedTotalText'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Réserver · $expectedTotalText'));
    await tester.pumpAndSettle();

    // Booking recap screen - with the default 1-night stay, "Prix par
    // nuit" and "Total" show the same formatted amount, so this just
    // confirms it's present (not that it's the only occurrence).
    expect(find.text('Récapitulatif'), findsOneWidget);
    expect(find.text(expectedTotalText), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la réservation'));
      await tester.pump();
      // Real POST /rooms/{id}/bookings round trip.
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    // Payment screen, still PENDING_PAYMENT.
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Réservation en attente de paiement'), findsOneWidget);
    expect(find.text(expectedTotalText), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer maintenant'));
      await tester.pump();
      // POST /hotel-bookings/{id}/payments (immediate "pending"
      // response), then the backend's own ~2s background task, then
      // this screen's single confirmation wait/lookup.
      await Future.delayed(const Duration(seconds: 18));
    });
    await tester.pumpAndSettle();

    expect(find.text('Réservation confirmée !'), findsOneWidget);
    expect(find.text(expectedTotalText), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
  });
}
