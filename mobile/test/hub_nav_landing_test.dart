// Real end-to-end test against the live local backend - no HTTP
// mocking. Dedicated regression test for the nav-bar-highlight bug
// found while building Commerce: every role used to land on /hub/home
// right after authenticating (fresh login/registration) or on session
// restore, but an owner role's own destinations (hub_destinations.dart)
// never include '/hub/home' - so HubScaffold's selectedIndex lookup
// found no match and fell back to position 0, visually highlighting
// that role's own tab (with its *selected* icon) despite Home actually
// being on screen. Fixed by landingRouteForRole routing every role
// straight to a screen that's genuinely one of its own destinations.
//
// This test logs in as each of the 4 owner-role fixture accounts (plus
// a fresh passenger) via session restore - the same path splash_screen.
// dart's _proceedPastSplash takes - and checks two things for each:
// the correct screen is actually showing, and the nav bar's *selected*
// icon is that role's own, not some other tab's.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';

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

/// Logs in as [email]/[password] (or registers a fresh passenger if
/// both are null), then pumps the real app from scratch - exercising
/// the exact session-restore path (SplashScreen -> _proceedPastSplash
/// -> landingRouteForRole) every relaunch goes through.
Future<void> _loginAndLandOnHub(WidgetTester tester, {String? email, String? password}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final authContainer = ProviderContainer();
  await tester.runAsync(() async {
    if (email != null && password != null) {
      await authContainer.read(authControllerProvider.notifier).login(email: email, password: password);
    } else {
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'NavLanding',
        lastName: 'Tester',
        email: 'flutter_hub_nav_landing_$uniqueSuffix@test.com',
        phone: '+224699000800',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    }
  });
  authContainer.dispose();

  await tester.runAsync(() async {
    await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 3)); // connectivity + session restore + splash hold
    await tester.pump(); // go_router redirects via landingRouteForRole
    await Future.delayed(const Duration(seconds: 2));
  });
  await tester.pumpAndSettle();
}

/// The NavigationBar always renders exactly 2 destinations for an
/// owner role (its own tab + Profil) - confirming the *selected* one
/// carries [expectedSelectedIcon] (not just that the icon exists
/// somewhere) is what actually verifies the highlight is on the right
/// tab, since NavigationBar swaps in a destination's `selectedIcon`
/// specifically (and only) for whichever index it considers current.
void _expectNavBarSelectedIcon(WidgetTester tester, IconData expectedSelectedIcon) {
  final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
  final selectedDestination = navBar.destinations[navBar.selectedIndex] as NavigationDestination;
  expect((selectedDestination.selectedIcon as Icon).icon, expectedSelectedIcon);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  testWidgets('passenger lands on Accueil with Accueil highlighted', (tester) async {
    await _loginAndLandOnHub(tester);

    expect(find.text('Où allez-vous aujourd\'hui ?'), findsOneWidget);
    _expectNavBarSelectedIcon(tester, Icons.home_rounded);
  });

  testWidgets('company_owner lands on Ma compagnie with Ma compagnie highlighted, not Accueil', (tester) async {
    await _loginAndLandOnHub(tester, email: 'company_owner_e2e_fixture@test.com', password: 'TestPass123!');

    // Matches twice now that the fix is in - the AppBar title *and* the
    // nav bar's own label for its correctly-highlighted destination
    // (labelBehavior: onlyShowSelected only shows a label at all for
    // whichever destination is actually selected).
    expect(find.text('Ma compagnie'), findsWidgets);
    expect(find.text('Où allez-vous aujourd\'hui ?'), findsNothing);
    _expectNavBarSelectedIcon(tester, Icons.apartment_rounded);
  });

  testWidgets('hotel_owner lands on Mon hôtel with Mon hôtel highlighted, not Accueil', (tester) async {
    await _loginAndLandOnHub(tester, email: 'hotel_owner_e2e_fixture@test.com', password: 'TestPass123!');

    expect(find.text('Mon hôtel'), findsWidgets);
    expect(find.text('Où allez-vous aujourd\'hui ?'), findsNothing);
    _expectNavBarSelectedIcon(tester, Icons.hotel_rounded);
  });

  testWidgets('event_organizer lands on Mes événements with Mes événements highlighted, not Accueil', (
    tester,
  ) async {
    await _loginAndLandOnHub(tester, email: 'event_organizer_e2e_fixture@test.com', password: 'TestPass123!');

    expect(find.text('Mes événements'), findsWidgets);
    expect(find.text('Où allez-vous aujourd\'hui ?'), findsNothing);
    _expectNavBarSelectedIcon(tester, Icons.event_rounded);
  });

  testWidgets('store_manager lands on Mes boutiques with Ma boutique highlighted, not Accueil', (tester) async {
    await _loginAndLandOnHub(tester, email: 'store_manager_e2e_fixture@test.com', password: 'TestPass123!');

    expect(find.text('Mes boutiques'), findsWidgets);
    expect(find.text('Où allez-vous aujourd\'hui ?'), findsNothing);
    _expectNavBarSelectedIcon(tester, Icons.storefront_rounded);
  });
}
