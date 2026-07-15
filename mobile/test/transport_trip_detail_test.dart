// Real end-to-end test against the live local backend - no HTTP
// mocking. Targets the seeded "Sily Express" morning trip
// (Conakry -> Kankan, 07:30, standard bus, 30 seats) directly by id.
// Seat "3" was pre-booked (PENDING_PAYMENT) via a throwaway account
// specifically so this test can verify the reserved visual state, not
// just the all-available case.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/transport/presentation/trip_detail_screen.dart';

const _tripId = '6a570f26ec6ed828b1a425d5';

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
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  testWidgets('trip detail shows bus/driver info and a seat map with a real reserved seat', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // getTripDetail alone is ~8 sequential real requests (route,
      // company, bus, driver, both stations, both cities).
      await Future.delayed(const Duration(seconds: 8));
      // The seat map section only mounts - and only then starts its
      // own GET .../seats fetch - once tripDetailProvider resolves and
      // the tree rebuilds past the loading state. Pump here, still
      // inside runAsync, so that fetch is created in the real zone
      // too, then give it its own real time to complete.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    // Route + company.
    expect(find.text('Sily Express'), findsOneWidget);
    expect(find.text('Conakry'), findsOneWidget);
    expect(find.text('Kankan'), findsOneWidget);

    // Bus + driver.
    expect(find.textContaining('Mercedes-Benz Sprinter'), findsOneWidget);
    expect(find.textContaining('Ibrahima Camara'), findsOneWidget);
    expect(find.text('Climatisation'), findsOneWidget);

    // Seat map: 30 seats rendered, seat "3" is reserved (untappable),
    // seat "1" is available (tappable).
    expect(find.text('1'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);

    // The seat map sits below the fold on the default test viewport -
    // scroll each seat into view before tapping it.
    await tester.ensureVisible(find.text('3'));
    await tester.pumpAndSettle();

    // Tapping the reserved seat does nothing - bottom bar stays empty.
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun siège sélectionné'), findsOneWidget);

    // Tapping an available window seat selects it and shows the
    // window-seat price (10% above the 250 000 FG base).
    await tester.ensureVisible(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('Siège 1'), findsOneWidget);
    expect(find.text('275 000 FG'), findsOneWidget);

    // Switching to an aisle seat shows the plain base price instead.
    await tester.ensureVisible(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Siège 2'), findsOneWidget);
    expect(find.text('250 000 FG'), findsOneWidget);

    expect(find.widgetWithText(ElevatedButton, 'Continuer'), findsOneWidget);
  });
}
