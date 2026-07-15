// Basic smoke test: the app boots and the splash screen's static brand
// elements render. backendConnectivityProvider is overridden with a
// never-resolving future rather than left to hit the real network -
// Dio's real connect-timeout timer would otherwise still be pending
// when the test binding tears down and fail the test on that alone.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/features/splash/splash_controller.dart';

void main() {
  testWidgets('App boots and shows the Guinea Go brand on the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendConnectivityProvider.overrideWith((ref) => Completer<String>().future),
        ],
        child: const GuineaGoApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Guinea Go'), findsOneWidget);
  });
}
