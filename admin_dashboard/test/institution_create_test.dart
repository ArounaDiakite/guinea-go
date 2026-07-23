// Real end-to-end test against the live local backend - no HTTP
// mocking. Drives the real "Créer un établissement public" form as a
// system_administrator, submits it, and confirms directly against the
// backend that both the school_administrator account and the public
// Institution were actually created, active immediately, and that the
// new administrator can really log in with the password entered in
// the form.

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
  final institutionName = 'École Publique E2E $uniqueSuffix';
  final adminEmail = 'institution_admin_e2e_$uniqueSuffix@test.com';
  const adminPassword = 'TestPass123!';

  String? createdInstitutionId;
  Options? adminAuthHeader;

  tearDownAll(() async {
    if (createdInstitutionId != null && adminAuthHeader != null) {
      try {
        await setupDio.delete<void>('/institutions/$createdInstitutionId', options: adminAuthHeader);
      } catch (_) {}
    }
    setupDio.close();
  });

  testWidgets('system_administrator creates a public institution, active immediately', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
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
      await tester.tap(find.text('Établissements'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2)); // countries + cities fetch
    });
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Créer un établissement public'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Public');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Admin$uniqueSuffix');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), adminEmail);
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224625000099');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ville (de l\'administrateur)'), 'Conakry');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), adminPassword);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom de l\'établissement'), institutionName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Adresse'), '1 Avenue de la République');

    // AdminShell's NavigationRail also has its own internal Scrollable,
    // so the default scrollUntilVisible() (which requires exactly one
    // Scrollable on screen) is ambiguous here - scope it to this form's
    // own SingleChildScrollView explicitly.
    final formScrollable = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;

    // warnIfMissed: false - the DropdownButtonFormField's own icon/
    // decoration layers sit exactly on top of the hint text at this
    // position, so the computed tap offset technically misses the Text
    // render object by a hair even though the tap still opens the
    // dropdown correctly every time.
    await tester.scrollUntilVisible(find.text('Choisir un pays').first, 200, scrollable: formScrollable);
    await tester.tap(find.text('Choisir un pays').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guinea').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Choisir une ville').first, 200, scrollable: formScrollable);
    await tester.tap(find.text('Choisir une ville').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conakry').last);
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(ElevatedButton, 'Créer l\'établissement');
    await tester.scrollUntilVisible(submitButton, 200, scrollable: formScrollable);
    await tester.runAsync(() async {
      await tester.tap(submitButton);
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('créé avec succès'), findsOneWidget);
    expect(find.text('Administrateur : $adminEmail'), findsOneWidget);

    // Verify directly against the backend: the account and the
    // institution are both real and active immediately.
    await tester.runAsync(() async {
      final loginResponse = await setupDio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': adminEmail, 'password': adminPassword},
      );
      expect(loginResponse.data!['user']['is_active'], isTrue);
      expect(loginResponse.data!['user']['role'], 'school_administrator');

      final token = loginResponse.data!['access_token'] as String;
      adminAuthHeader = Options(headers: {'Authorization': 'Bearer $token'});

      final institutionResponse = await setupDio.get<Map<String, dynamic>>(
        '/institutions/me',
        options: adminAuthHeader,
      );
      expect(institutionResponse.data!['name'], institutionName);
      expect(institutionResponse.data!['institution_type'], 'primary_public');
      expect(institutionResponse.data!['is_active'], isTrue);
      createdInstitutionId = institutionResponse.data!['id'] as String;
    });
  });
}
