// Real end-to-end test against the live local backend (127.0.0.1:8000,
// same default AppConfig.apiBaseUrl points at) - no HTTP mocking. Only
// flutter_secure_storage's platform channel is mocked (with an in-
// memory map standing in for the OS-backed store), since platform
// channels don't exist in a bare `flutter test` VM run; the channel
// name/argument shape below was confirmed empirically against the
// installed package version, not guessed.
//
// Requires the backend running locally before `flutter test` - these
// tests hit real endpoints and will fail with connection errors
// otherwise, which is the intended, honest failure mode.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/hub/presentation/home_hub_screen.dart';
import 'package:guinea_go/features/hub/presentation/hub_scaffold.dart';
import 'package:guinea_go/features/hub/presentation/module_placeholder_screen.dart';
import 'package:guinea_go/features/hub/presentation/profile_screen.dart';
import 'package:guinea_go/features/identity/presentation/login_screen.dart';
import 'package:guinea_go/features/identity/presentation/register_screen.dart';

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

/// Mirrors app.dart's route table (minus the splash screen, which most
/// tests don't need to sit through) with its own fresh GoRouter per
/// call - deliberately not reusing the app's global `appRouter`
/// singleton, so navigation state from one test can't leak into the
/// next. The one test that needs the splash's session-restore redirect
/// uses GuineaGoApp/appRouter directly instead (see below).
Widget buildTestApp(String initialLocation) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HubScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/hub/home', builder: (context, state) => const HomeHubScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub/transport',
                builder: (context, state) =>
                    const ModulePlaceholderScreen(title: 'Transport', icon: Icons.directions_bus_rounded),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub/hotels',
                builder: (context, state) =>
                    const ModulePlaceholderScreen(title: 'Hôtels', icon: Icons.hotel_rounded),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub/events',
                builder: (context, state) => const ModulePlaceholderScreen(
                  title: 'Événements',
                  icon: Icons.confirmation_number_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub/commerce',
                builder: (context, state) =>
                    const ModulePlaceholderScreen(title: 'Commerce', icon: Icons.storefront_rounded),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub/education',
                builder: (context, state) =>
                    const ModulePlaceholderScreen(title: 'Éducation', icon: Icons.school_rounded),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/hub/profile', builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter test's binding installs a global HttpOverrides that fakes
  // every dart:io HttpClient response as a 400 with no real network
  // call - clearing it here restores real networking for this suite,
  // which is the whole point: these tests must hit the real backend.
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  // Shared across the ordered tests below: register once, then log
  // back in with the same credentials, then attempt to register the
  // same email again to hit the duplicate-email path.
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  // .test is an RFC 2606 reserved TLD - the backend's EmailStr
  // validator (correctly) rejects it as undeliverable, so this uses
  // the same throwaway-domain pattern as the backend's own test suite.
  final testEmail = 'flutter_test_$uniqueSuffix@test.com';
  const testPassword = 'TestPass123!';

  testWidgets('register a new passenger lands on the hub home', (tester) async {
    await tester.pumpWidget(buildTestApp('/register'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Mariam');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Bah');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224620000099');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), testPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer mon compte'));
      // Let the real HTTP round-trip to the backend actually complete.
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Mariam'), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
    expect(storedToken, isNotEmpty);
    // JWTs are three dot-separated base64url segments.
    expect(storedToken!.split('.').length, 3);
  });

  testWidgets('registering the same email again is rejected with a clear message', (tester) async {
    await tester.pumpWidget(buildTestApp('/register'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Mariam');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Bah');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224620000099');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), testPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer mon compte'));
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    // Still on the register screen, with the backend's own French
    // error message surfaced verbatim.
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Cet email est déjà utilisé.'), findsOneWidget);
  });

  testWidgets('logging in with the just-registered credentials works and stores a fresh token', (tester) async {
    // Start from a clean slate - no token from the previous test.
    await TokenStorage.clear();

    await tester.pumpWidget(buildTestApp('/login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), testPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Mariam'), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
    expect(storedToken!.split('.').length, 3);
  });

  testWidgets('a valid stored token restores the session straight to the hub, without login', (tester) async {
    // The token left over from the previous (login) test is still in
    // the mocked secure storage - this simulates relaunching the app,
    // or reloading the web page, with a still-valid session rather
    // than going through a fresh login.
    final tokenBeforeRelaunch = await TokenStorage.readAccessToken();
    expect(tokenBeforeRelaunch, isNotNull, reason: 'expected a token left over from the login test');

    // Uses the app's real router (starting at "/", the splash screen)
    // rather than buildTestApp's shortcut router, since it's the
    // splash screen's redirect logic under test here. pumpWidget
    // itself has to run inside runAsync, not just the delay after it -
    // otherwise the connectivity fetch it triggers is created in
    // flutter_test's fake-async zone, and pumpAndSettle's frame
    // pumping fast-forwards that fake clock straight past Dio's real
    // 15s connect timeout before the real socket response ever lands.
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
      await tester.pump();
      // Real connectivity check, then the session-restore GET
      // /users/me, then the splash screen's own 500ms hold.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Mariam'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('a deep link straight to a /hub route without a session redirects to login', (tester) async {
    // No token in storage at all - simulates an OS-level deep link (a
    // notification tap, a shared URL, ...) opening the app straight on
    // a /hub/* route, bypassing the splash screen entirely. The router
    // guard, not the splash screen's own session-restore flow, is what
    // has to catch this.
    await TokenStorage.clear();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [initialLocationProvider.overrideWithValue('/hub/transport/bookings')],
          child: const GuineaGoApp(),
        ),
      );
      await tester.pump();
      // The guard awaits authControllerProvider.future (a secure-storage
      // read, no network call) before deciding - generous margin still
      // covers it comfortably.
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HubScaffold), findsNothing);
  });

  testWidgets('logging in with a wrong password shows the backend error and stores nothing', (tester) async {
    await TokenStorage.clear();

    await tester.pumpWidget(buildTestApp('/login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'WrongPassword123!');

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    expect(await TokenStorage.readAccessToken(), isNull);
  });

  testWidgets('hub flow: login, browse every module, view the profile, then log out', (tester) async {
    await TokenStorage.clear();

    // Bottom nav bar is a mobile layout (HubScaffold switches to a
    // side rail at 720dp) - force a phone-sized surface so this test
    // exercises that path, per the task's "bottom nav bar sur mobile".
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp('/login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), testPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Mariam'), findsOneWidget);

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    const modules = [
      (icon: Icons.directions_bus_outlined, title: 'Transport'),
      (icon: Icons.hotel_outlined, title: 'Hôtels'),
      (icon: Icons.confirmation_number_outlined, title: 'Événements'),
      (icon: Icons.storefront_outlined, title: 'Commerce'),
      (icon: Icons.school_outlined, title: 'Éducation'),
    ];

    for (final module in modules) {
      await tester.tap(find.descendant(of: navBar, matching: find.byIcon(module.icon)));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, module.title), findsOneWidget);
      expect(find.text('Module en construction'), findsOneWidget);
    }

    // Profil tab: real user info from the account created earlier.
    await tester.tap(find.descendant(of: navBar, matching: find.byIcon(Icons.person_outline_rounded)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Profil'), findsOneWidget);
    expect(find.text('Mariam Bah'), findsOneWidget);
    expect(find.text(testEmail), findsOneWidget);
    expect(find.text('Passager'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(await TokenStorage.readAccessToken(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
