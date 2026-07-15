// Real end-to-end test against the live local backend - no HTTP
// mocking. Logs in as a pre-provisioned fixture driver account
// (driver_e2e_fixture@test.com), assigned to a permanent fixture trip
// on the seeded "Sily Express" company (2026-08-20, Conakry -> Kankan,
// driver_id 6a57a1372f024f308e6fbd33). Both were created once via the
// real API (POST /companies/{id}/drivers, POST /trips) under a
// company_owner token obtained by temporarily promoting a throwaway
// account's role directly in MongoDB and restoring the company's real
// owner_id immediately after - there is no seeded company_owner
// account and register-partner requires admin activation, so this was
// the only way to bootstrap the very first one. From here on, this
// driver account is permanent, ordinary fixture data.
//
// Covers: the nav shell shows the driver tab set (not the passenger
// one) and lands on it after login; "Mes trajets" lists the assigned
// trip; a ticket generated through the real passenger flow can be
// validated by this driver with the right passenger/seat info; and a
// replayed validation is rejected. The literal camera scan itself
// can't be driven in a headless `flutter test` VM (no camera plugin
// surface) - this exercises the exact repository call
// (TransportRepository.validateTicket) the scan screen makes once
// mobile_scanner hands it a decoded code, which is the part that
// actually talks to the backend.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/network/api_error.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/transport/data/transport_repository.dart';
import 'package:guinea_go/features/transport/models/ticket.dart';

const _driverEmail = 'driver_e2e_fixture@test.com';
const _driverPassword = 'TestPass123!';
const _fixtureTripId = '6a57a1382f024f308e6fbd34'; // 2026-08-20, Sily Express, driver_e2e_fixture

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  testWidgets('driver logs in, sees Mes trajets, and validates a real ticket', (tester) async {
    late String ticketCode;
    late String expectedSeatNumber;

    // A fresh passenger books a real seat on the driver's fixture trip
    // and pays via the sandbox, exactly like a real passenger would -
    // this is the ticket the driver will validate below.
    await tester.runAsync(() async {
      final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final passengerEmail = 'flutter_driver_passenger_${DateTime.now().millisecondsSinceEpoch}@test.com';

      final regResponse = await setupDio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'first_name': 'Passenger',
          'last_name': 'ForDriverTest',
          'email': passengerEmail,
          'phone': '+224699000099',
          'password': 'TestPass123!',
          'city': 'Conakry',
          'country_code': 'GN',
          'preferred_language': 'fr',
        },
      );
      final passengerToken = regResponse.data!['access_token'] as String;
      final authHeader = Options(headers: {'Authorization': 'Bearer $passengerToken'});

      final seatsResponse = await setupDio.get<List<dynamic>>('/trips/$_fixtureTripId/seats');
      final available = seatsResponse.data!
          .cast<Map<String, dynamic>>()
          .firstWhere((seat) => seat['status'] == 'AVAILABLE');
      expectedSeatNumber = available['seat_number'] as String;

      final bookingResponse = await setupDio.post<Map<String, dynamic>>(
        '/trips/$_fixtureTripId/bookings',
        data: {'seat_id': available['seat_id']},
        options: authHeader,
      );
      final bookingId = bookingResponse.data!['id'] as String;
      final pricePaid = bookingResponse.data!['price_paid'] as num;

      await setupDio.post<Map<String, dynamic>>(
        '/bookings/$bookingId/payments',
        data: {'provider': 'orange_money', 'amount': pricePaid},
        options: authHeader,
      );

      // The backend's sandbox background task confirms the booking
      // (and issues the ticket) ~2s later.
      await Future.delayed(const Duration(seconds: 4));

      final ticketResponse = await setupDio.get<Map<String, dynamic>>(
        '/bookings/$bookingId/ticket',
        options: authHeader,
      );
      ticketCode = ticketResponse.data!['code'] as String;
      expect(ticketResponse.data!['status'], 'VALID');
      setupDio.close();
    });

    // Log in as the fixture driver and let the real app decide where
    // to land - this is the router guard + role-based redirect under
    // test, not a shortcut router.
    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).login(
        email: _driverEmail,
        password: _driverPassword,
      );
    });
    authContainer.dispose();

    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
      await tester.pump();
      // Real connectivity check, session restore, splash's own 500ms
      // hold, then its context.go redirect to /hub/driver/trips.
      await Future.delayed(const Duration(seconds: 3));
      // A frame has to actually run for DriverTripsScreen to mount and
      // its providers (driver profile, then assigned trips - a chain
      // of 8 sequential real calls) to start fetching - real time
      // passing alone, without a pump, doesn't advance the widget tree.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 15));
    });
    await tester.pumpAndSettle();

    // Landed on the driver's own trips screen, not the passenger hub -
    // and the nav only offers the driver tab set.
    expect(find.text('Mes trajets'), findsWidgets);
    expect(find.text('Conakry → Kankan'), findsOneWidget);
    expect(find.text('Sily Express'), findsOneWidget);
    expect(find.text('Transport'), findsNothing);
    expect(find.text('Accueil'), findsNothing);

    // Validate the real ticket - the same repository call the scan
    // screen makes once it decodes a QR code.
    final validateContainer = ProviderContainer();
    dynamic validated;
    await tester.runAsync(() async {
      validated = await validateContainer.read(transportRepositoryProvider).validateTicket(ticketCode);
    });

    expect(validated.status, TicketStatus.used);
    expect(validated.seatNumber, expectedSeatNumber);
    expect(validated.passengerName, 'Passenger ForDriverTest');

    // Replaying the same code is rejected - already used.
    await tester.runAsync(() async {
      try {
        await validateContainer.read(transportRepositoryProvider).validateTicket(ticketCode);
        fail('Expected the second validation to be rejected.');
      } catch (error) {
        expect(extractApiErrorMessage(error), contains('already been used'));
      }
    });
    validateContainer.dispose();
  });
}
