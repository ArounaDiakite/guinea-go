// Real end-to-end test against the live local backend - no HTTP
// mocking, same pattern as auth_flow_test.dart. Requires the seeded
// Conakry <-> Kankan route/trips created for this feature (2 trips
// today, both operated by "Sily Express").

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/transport/models/trip_search_params.dart';
import 'package:guinea_go/features/transport/presentation/results_screen.dart';
import 'package:guinea_go/features/transport/presentation/search_screen.dart';

// Every Dio request goes through _AuthInterceptor, which reads the
// stored token via flutter_secure_storage even for public endpoints -
// its platform channel doesn't exist in a bare `flutter test` VM run,
// so it needs a mock here too (same one auth_flow_test.dart uses),
// even though this test never actually logs in.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  testWidgets('search Conakry -> Kankan today returns the two seeded trips, sortable', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      await Future.delayed(const Duration(seconds: 2));
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
      // needs more real time than a single round trip.
      await Future.delayed(const Duration(seconds: 8));
    });
    await tester.pumpAndSettle();

    expect(find.text('Conakry → Kankan'), findsOneWidget);
    expect(find.text('2 trajets'), findsOneWidget);
    expect(find.text('Sily Express'), findsNWidgets(2));
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);

    // Sort chips are tappable and don't blow up the list.
    await tester.tap(find.text('Prix'));
    await tester.pumpAndSettle();
    expect(find.text('2 trajets'), findsOneWidget);
  });
}
