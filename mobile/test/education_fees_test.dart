// Real end-to-end test against the live local backend - no HTTP
// mocking. Covers Step 4 (the last one) of the Education module:
// FeeSchedule creation, applying it to a student (StudentFee), two
// cumulative partial payments (proving payments genuinely accumulate
// and never expire, unlike a transport booking's payment window), and
// the resulting fee/payment history.
//
// Builds its own throwaway institution/class/student fixture fresh in
// setUpAll via the API - institution/class/student creation through
// the real UI is already covered end-to-end by
// education_school_setup_test.dart, so this test seeds that directly
// and focuses on what's new in this step. Uses a FOURTH dedicated
// school_administrator_fees_e2e_fixture account, since a school_
// administrator can only ever administer one institution and sharing
// any of the other three fixtures would race over that 1:1 slot
// whenever multiple test files run concurrently (flutter test's
// default).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';

const _adminEmail = 'school_administrator_fees_e2e_fixture@test.com';
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

Future<void> _tapAndSettle(WidgetTester tester, Finder finder, {Duration wait = const Duration(seconds: 2)}) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future.delayed(wait);
  });
  await tester.pumpAndSettle();
}

Future<void> _pageBackAndSettle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pageBack();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
  });
  await tester.pumpAndSettle();
}

Future<void> _submitAndSettle(
  WidgetTester tester,
  Finder submitButton, {
  Duration wait = const Duration(seconds: 4),
}) async {
  await tester.scrollUntilVisible(submitButton, 100, scrollable: find.byType(Scrollable).first);
  await tester.runAsync(() async {
    await tester.tap(submitButton);
    await tester.pump();
    await Future.delayed(wait);
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  final unitName = 'CM1 Frais E2E $uniqueSuffix';
  final feeScheduleName = 'Frais de scolarité E2E $uniqueSuffix';
  final studentFullName = 'Fatoumata Camara$uniqueSuffix';

  late Options adminAuthHeader;
  late String institutionId;
  late String studentId;

  setUpAll(() async {
    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _adminEmail, 'password': _adminPassword},
    );
    final token = loginResponse.data!['access_token'] as String;
    adminAuthHeader = Options(headers: {'Authorization': 'Bearer $token'});

    try {
      final existing = await setupDio.get<Map<String, dynamic>>('/institutions/me', options: adminAuthHeader);
      await setupDio.delete<void>('/institutions/${existing.data!['id']}', options: adminAuthHeader);
    } catch (_) {}

    final countriesResponse = await setupDio.get<List<dynamic>>('/countries/');
    final guinea = countriesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['code'] == 'GN');
    final citiesResponse = await setupDio.get<List<dynamic>>('/cities/', queryParameters: {'limit': 100});
    final conakryCity = citiesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Conakry');

    final institutionResponse = await setupDio.post<Map<String, dynamic>>(
      '/institutions/',
      data: {
        'name': 'École Frais E2E $uniqueSuffix',
        'address': 'Kaloum, Conakry',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'institution_type': 'primary_private',
      },
      options: adminAuthHeader,
    );
    institutionId = institutionResponse.data!['id'] as String;

    final unitResponse = await setupDio.post<Map<String, dynamic>>(
      '/academic-units/',
      data: {'institution_id': institutionId, 'name': unitName, 'level': 'CM1'},
      options: adminAuthHeader,
    );
    final academicUnitId = unitResponse.data!['id'] as String;

    final studentResponse = await setupDio.post<Map<String, dynamic>>(
      '/students/',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': academicUnitId,
        'first_name': 'Fatoumata',
        'last_name': 'Camara$uniqueSuffix',
      },
      options: adminAuthHeader,
    );
    studentId = studentResponse.data!['id'] as String;
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/institutions/$institutionId', options: adminAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets(
    'school_administrator creates a fee schedule, applies it, and records two cumulative payments',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authContainer = ProviderContainer();
      await tester.runAsync(() async {
        await authContainer.read(authControllerProvider.notifier).login(
          email: _adminEmail,
          password: _adminPassword,
        );
      });
      authContainer.dispose();

      await tester.runAsync(() async {
        await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // connectivity + session restore + splash hold
        await tester.pump(); // go_router redirects straight to /hub/school
        await Future.delayed(const Duration(seconds: 2)); // myInstitutionProvider resolves - institution exists now
      });
      await tester.pumpAndSettle();

      expect(find.text('Gestion'), findsOneWidget);

      // --- FeeSchedule creation ---
      await _tapAndSettle(tester, find.text('Frais de scolarité'));
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom des frais'), feeScheduleName);
      await tester.enterText(find.widgetWithText(TextFormField, 'Montant (GNF)'), '200000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Période'), 'Trimestriel');
      // Scope left on its default "Tout l'établissement" - an
      // institution-wide fee, the common case.

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer les frais'));

      expect(find.text(feeScheduleName), findsOneWidget);
      expect(find.text('200 000 FG'), findsOneWidget);

      // --- Apply the fee to the student ---
      await _pageBackAndSettle(tester);
      expect(find.text('Gestion'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Élèves'));
      expect(find.text(studentFullName), findsOneWidget);

      await _tapAndSettle(tester, find.byTooltip('Frais de scolarité').first);
      expect(find.text('Frais de scolarité'), findsOneWidget);
      expect(find.text('Aucuns frais appliqués à cet élève pour le moment.'), findsOneWidget);

      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.runAsync(() async {
        // feeSchedulesProvider + studentDetailProvider + studentFeesProvider.
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();

      expect(find.text(feeScheduleName), findsOneWidget);
      await _tapAndSettle(tester, find.text(feeScheduleName), wait: const Duration(seconds: 3));

      // Back on the (now non-empty) history screen.
      expect(find.text('Frais de scolarité'), findsOneWidget);
      expect(find.text('Impayé'), findsOneWidget);
      expect(find.text('0 FG / 200 000 FG'), findsOneWidget);

      // --- First payment: partial ---
      await _tapAndSettle(tester, find.text(feeScheduleName));

      expect(find.text('Paiement des frais'), findsOneWidget);
      expect(find.text('200 000 FG'), findsWidgets); // "Montant dû" and "Solde restant" both read it pre-payment

      await tester.enterText(find.widgetWithText(TextFormField, 'Montant à payer (GNF)'), '80000');
      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Enregistrer le paiement'), wait: const Duration(seconds: 8));

      expect(find.text('Paiement enregistré !'), findsOneWidget);
      expect(find.text('Reste 120 000 FG sur 200 000 FG'), findsOneWidget);

      await _tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'Retour à l\'historique'));

      expect(find.text('Frais de scolarité'), findsOneWidget);
      expect(find.text('Partiellement payé'), findsOneWidget);
      expect(find.text('80 000 FG / 200 000 FG'), findsOneWidget);
      expect(find.text('Reste 120 000 FG'), findsOneWidget);

      // --- Second payment: the remaining balance, pre-filled automatically ---
      await _tapAndSettle(tester, find.text(feeScheduleName));

      expect(find.text('Paiement des frais'), findsOneWidget);
      // The amount field is pre-filled with the CURRENT remaining
      // balance (not the original amount_due) - submit as-is, without
      // typing anything, to prove that pre-fill genuinely reflects the
      // first payment already applied.
      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Enregistrer le paiement'), wait: const Duration(seconds: 8));

      expect(find.text('Paiement enregistré !'), findsOneWidget);
      expect(find.text('Frais entièrement payés (200 000 FG)'), findsOneWidget);

      await _tapAndSettle(tester, find.widgetWithText(ElevatedButton, 'Retour à l\'historique'));

      expect(find.text('Frais de scolarité'), findsOneWidget);
      expect(find.text('Payé'), findsOneWidget);
      expect(find.text('200 000 FG / 200 000 FG'), findsOneWidget);
      expect(find.textContaining('Reste'), findsNothing);

      // Verify directly against the backend - the real thing under
      // test, independent of whatever the UI happens to still show.
      await tester.runAsync(() async {
        final checkResponse = await setupDio.get<List<dynamic>>(
          '/students/$studentId/fees',
          options: adminAuthHeader,
        );
        final fees = checkResponse.data!.cast<Map<String, dynamic>>();
        final fee = fees.firstWhere((f) => f['fee_schedule_name'] == feeScheduleName);

        expect(fee['status'], 'paid');
        expect((fee['amount_paid'] as num).toDouble(), 200000.0);
        expect((fee['amount_due'] as num).toDouble(), 200000.0);

        final payments = (fee['payments'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(payments.length, 2);
        for (final payment in payments) {
          expect(payment['status'], 'completed');
        }
        final totalPaid = payments.fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble());
        expect(totalPaid, 200000.0);
      });
    },
  );
}
