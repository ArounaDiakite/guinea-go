// Real end-to-end test against the live local backend - no HTTP
// mocking. Builds its own dedicated company/bus/driver/route/schedule/
// trip fixture in setUpAll (mirroring transport_search_test.dart and
// transport_ticket_test.dart) rather than logging in as the permanent
// driver_e2e_fixture@test.com account assigned to a fixed seeded trip.
// getMyDriverProfile()/getAssignedTrips() both resolve from the
// logged-in driver's own token server-side, so a freshly-created
// driver account (with its own email/password) assigned to this run's
// own trip works exactly the same way the old fixture account did -
// without depending on a trip whose seats get permanently exhausted
// by the accumulated weight of every past run against it (confirmed
// happening after enough runs this session).
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
  late String driverEmail;
  const driverPassword = 'TestPass123!';

  setUpAll(() async {
    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    companyName = 'Driver E2E $uniqueSuffix';
    driverEmail = 'driver_e2e_$uniqueSuffix@test.com';

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
        'phone': '+224631000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'email': 'driver_e2e_company_$uniqueSuffix@test.com',
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
        'registration_number': 'RC-DR-$uniqueSuffix',
        'fleet_number': 'F-DR-$uniqueSuffix',
        'brand': 'Mercedes',
        'model': 'Sprinter',
        'manufacture_year': 2024,
        'seat_capacity': 30,
        'bus_type': 'STANDARD',
      },
      options: ownerAuthHeader,
    );
    final busId = busResponse.data!['id'] as String;
    await setupDio.post<void>('/buses/$busId/generate-seats', options: ownerAuthHeader);

    final driverResponse = await setupDio.post<Map<String, dynamic>>(
      '/companies/$companyId/drivers',
      data: {
        'first_name': 'Driver',
        'last_name': 'E2E Test',
        'email': driverEmail,
        'phone': '+224632000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 6)}',
        'password': driverPassword,
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'profile': {
          'employee_number': 'EMP-DR-$uniqueSuffix',
          'gender': 'MALE',
          'date_of_birth': '1990-01-01',
          'license_number': 'LIC-DR-$uniqueSuffix',
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
        'route_code': 'DR-$uniqueSuffix',
        'name': 'Conakry - Kankan Driver E2E $uniqueSuffix',
        'origin_station_id': originStation['id'],
        'destination_station_id': destinationStation['id'],
        'distance_km': 620,
        'estimated_duration_minutes': 540,
        'base_price': 250000,
      },
      options: ownerAuthHeader,
    );
    routeId = routeResponse.data!['id'] as String;

    final scheduleResponse = await setupDio.post<Map<String, dynamic>>(
      '/schedules/',
      data: {
        'company_id': companyId,
        'route_id': routeId,
        'departure_time': '10:00:00',
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
        'price': 250000,
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

  testWidgets('driver logs in, sees Mes trajets, and validates a real ticket', (tester) async {
    late String ticketCode;
    late String expectedSeatNumber;

    // A fresh passenger books a real seat on this run's own trip and
    // pays via the sandbox, exactly like a real passenger would - this
    // is the ticket the driver will validate below.
    await tester.runAsync(() async {
      final passengerDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final passengerEmail = 'flutter_driver_passenger_${DateTime.now().millisecondsSinceEpoch}@test.com';

      final regResponse = await passengerDio.post<Map<String, dynamic>>(
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

      final seatsResponse = await passengerDio.get<List<dynamic>>('/trips/$tripId/seats');
      final available = seatsResponse.data!
          .cast<Map<String, dynamic>>()
          .firstWhere((seat) => seat['status'] == 'AVAILABLE');
      expectedSeatNumber = available['seat_number'] as String;

      final bookingResponse = await passengerDio.post<Map<String, dynamic>>(
        '/trips/$tripId/bookings',
        data: {'seat_id': available['seat_id']},
        options: authHeader,
      );
      final bookingId = bookingResponse.data!['id'] as String;
      final pricePaid = bookingResponse.data!['price_paid'] as num;

      await passengerDio.post<Map<String, dynamic>>(
        '/bookings/$bookingId/payments',
        data: {'provider': 'orange_money', 'amount': pricePaid},
        options: authHeader,
      );

      // The backend's sandbox background task confirms the booking
      // (and issues the ticket) ~2s later.
      await Future.delayed(const Duration(seconds: 4));

      final ticketResponse = await passengerDio.get<Map<String, dynamic>>(
        '/bookings/$bookingId/ticket',
        options: authHeader,
      );
      ticketCode = ticketResponse.data!['code'] as String;
      expect(ticketResponse.data!['status'], 'VALID');
      passengerDio.close();
    });

    // Log in as this run's own fresh driver and let the real app
    // decide where to land - this is the router guard + role-based
    // redirect under test, not a shortcut router.
    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).login(
        email: driverEmail,
        password: driverPassword,
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
    expect(find.text(companyName), findsOneWidget);
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
