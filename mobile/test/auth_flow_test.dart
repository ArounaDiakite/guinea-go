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

import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/home/home_screen.dart';
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

Widget buildTestApp(String initialLocation) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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

  testWidgets('register a new passenger against the real backend', (tester) async {
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

    expect(find.textContaining('Connecté en tant que Mariam'), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
    expect(storedToken, isNotEmpty);
    // eslint: JWTs are three dot-separated base64url segments.
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

    expect(find.textContaining('Connecté en tant que Mariam'), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
    expect(storedToken!.split('.').length, 3);
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

  testWidgets('logging out clears the stored token', (tester) async {
    await tester.pumpWidget(buildTestApp('/login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), testEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), testPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(await TokenStorage.readAccessToken(), isNotNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Se déconnecter'));
    await tester.pumpAndSettle();

    expect(await TokenStorage.readAccessToken(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
