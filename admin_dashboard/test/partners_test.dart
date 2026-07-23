// Real end-to-end test against the live local backend - no HTTP
// mocking. Registers a fresh throwaway company_owner partner account
// per run (POST /auth/register-partner, inactive by design - see
// AuthService.register_partner), confirms it shows up in the
// system_administrator's pending list, opens its detail screen,
// activates it for real, and confirms both that it disappears from the
// pending list and that the account can now actually log in.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_dashboard/app.dart';
import 'package:admin_dashboard/core/config/app_config.dart';
import 'package:admin_dashboard/core/network/token_storage.dart';

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

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  final partnerEmail = 'partner_e2e_$uniqueSuffix@test.com';
  const partnerPassword = 'TestPass123!';
  final partnerFullName = 'Aissatou PartnerE2E$uniqueSuffix';

  setUpAll(() async {
    await setupDio.post<void>(
      '/auth/register-partner',
      data: {
        'first_name': 'Aissatou',
        'last_name': 'PartnerE2E$uniqueSuffix',
        'email': partnerEmail,
        'phone': '+224624000${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 3)}',
        'password': partnerPassword,
        'city': 'Conakry',
        'country_code': 'GN',
        'preferred_language': 'fr',
        'role': 'company_owner',
      },
    );
  });

  tearDownAll(() {
    setupDio.close();
  });

  testWidgets(
    'a pending partner shows up in the list, its detail is viewable, and activating it lets it log in',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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

      await tester.runAsync(() async {
        await tester.tap(find.text('Partenaires'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Comptes en attente de validation'), findsOneWidget);
      expect(find.text(partnerFullName), findsOneWidget);
      expect(find.textContaining('Propriétaire de compagnie'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.text(partnerFullName));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Détail du compte'), findsOneWidget);
      expect(find.text(partnerEmail), findsOneWidget);
      expect(find.text('Conakry'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Activer ce compte'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2)); // PATCH activate + pop back to the list
        await tester.pump(); // pendingUsersProvider invalidated, refetch starts
        await Future.delayed(const Duration(seconds: 2)); // refetch completes
      });
      await tester.pumpAndSettle();

      // Back on the (now refreshed) pending list, without the just-
      // activated partner.
      expect(find.widgetWithText(AppBar, 'Comptes en attente de validation'), findsOneWidget);
      expect(find.text(partnerFullName), findsNothing);

      // The real proof: the activated account can now log in.
      await tester.runAsync(() async {
        final response = await setupDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': partnerEmail, 'password': partnerPassword},
        );
        expect(response.data!['user']['is_active'], isTrue);
        expect(response.data!['user']['role'], 'company_owner');
      });
    },
  );
}
