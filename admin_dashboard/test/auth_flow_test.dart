// Real end-to-end test against the live local backend - no HTTP
// mocking. Uses a persistent system_administrator_e2e_fixture account
// (system_administrator has no self-registration path at all - see
// AuthController's doc comment - so unlike mobile/'s tests, there is
// no register step to create one per run; it was created once directly
// via AuthService.register_role from a one-off script). The rejected-
// login case registers its own fresh throwaway passenger account per
// run (via a raw call to /auth/register, since this app itself has no
// register screen to drive).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_dashboard/app.dart';
import 'package:admin_dashboard/core/config/app_config.dart';
import 'package:admin_dashboard/core/network/token_storage.dart';
import 'package:admin_dashboard/features/identity/presentation/login_screen.dart';

const _adminEmail = 'system_administrator_e2e_fixture@test.com';
const _adminPassword = 'TestPass123!';

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

  testWidgets('system_administrator logs in and lands on the dashboard', (tester) async {
    await TokenStorage.clear();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [initialLocationProvider.overrideWithValue('/login')],
          child: const AdminDashboardApp(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), _adminEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), _adminPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Tableau de bord'), findsOneWidget);
    expect(find.text('Bienvenue, System'), findsOneWidget);

    final storedToken = await TokenStorage.readAccessToken();
    expect(storedToken, isNotNull);
    expect(storedToken!.split('.').length, 3);
  });

  testWidgets(
    'a valid stored session restores straight to the dashboard, without login, '
    'and logging out returns to the login screen and clears it',
    (tester) async {
      final tokenBeforeRelaunch = await TokenStorage.readAccessToken();
      expect(tokenBeforeRelaunch, isNotNull, reason: 'expected a token left over from the previous test');

      await tester.runAsync(() async {
        await tester.pumpWidget(const ProviderScope(child: AdminDashboardApp()));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Tableau de bord'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Se déconnecter'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await TokenStorage.readAccessToken(), isNull);
    },
  );

  testWidgets('a non-system_administrator login is rejected with a clear message and no session', (tester) async {
    await TokenStorage.clear();

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final passengerEmail = 'admin_dashboard_rejected_e2e_$uniqueSuffix@test.com';
    const passengerPassword = 'TestPass123!';

    await tester.runAsync(() async {
      final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      await setupDio.post<void>(
        '/auth/register',
        data: {
          'first_name': 'Rejected',
          'last_name': 'Passenger',
          'email': passengerEmail,
          'phone': '+224623000099',
          'password': passengerPassword,
          'city': 'Conakry',
          'country_code': 'GN',
          'preferred_language': 'fr',
        },
      );
      setupDio.close();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [initialLocationProvider.overrideWithValue('/login')],
          child: const AdminDashboardApp(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), passengerEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), passengerPassword);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Cet espace est réservé aux administrateurs système.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(await TokenStorage.readAccessToken(), isNull);
  });

  testWidgets('logging in with a wrong password shows the backend error and stores nothing', (tester) async {
    await TokenStorage.clear();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [initialLocationProvider.overrideWithValue('/login')],
          child: const AdminDashboardApp(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), _adminEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'WrongPassword123!');

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    expect(await TokenStorage.readAccessToken(), isNull);
  });

  testWidgets('a deep link without a session redirects to login', (tester) async {
    await TokenStorage.clear();

    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: AdminDashboardApp()));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
