// Real end-to-end test against the live local backend - no HTTP
// mocking. Uses its own dedicated school_administrator_schedule_e2e_
// fixture account (bootstrapped the same way as school_administrator_
// e2e_fixture - see education_school_setup_test.dart for that story) -
// NOT the plain school_administrator_e2e_fixture, because a school_
// administrator can only ever administer one institution, and that
// other fixture's own test deletes/recreates its institution in
// setUpAll too. Sharing the account would race two test files fighting
// over the same 1:1 institution slot whenever both run concurrently
// (flutter test's default). Seeds its institution + a class + a
// teacher directly via the API in setUpAll (fast setup) - the
// institution/class/teacher creation flow through the real UI is
// already covered end-to-end by education_school_setup_test.dart, so
// this test focuses on what's new in this step: subjects and the
// timetable itself.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/features/education/models/subject.dart';
import 'package:guinea_go/features/education/models/teacher.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';

const _adminEmail = 'school_administrator_schedule_e2e_fixture@test.com';
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

Future<void> _selectDropdownItem(WidgetTester tester, Finder dropdownFinder, String itemText) async {
  await tester.scrollUntilVisible(dropdownFinder, 100, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  final subjectName = 'Maths E2E $uniqueSuffix';

  late Options adminAuthHeader;
  late String institutionId;
  late String academicUnitId;
  late String unitName;
  late String teacherFullName;

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
        'name': 'École Emploi du temps E2E $uniqueSuffix',
        'address': 'Kaloum, Conakry',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'institution_type': 'primary_private',
      },
      options: adminAuthHeader,
    );
    institutionId = institutionResponse.data!['id'] as String;

    unitName = 'CM1 E2E $uniqueSuffix';
    final unitResponse = await setupDio.post<Map<String, dynamic>>(
      '/academic-units/',
      data: {'institution_id': institutionId, 'name': unitName, 'level': 'CM1'},
      options: adminAuthHeader,
    );
    academicUnitId = unitResponse.data!['id'] as String;

    teacherFullName = 'Prof Emploi$uniqueSuffix';
    await setupDio.post<Map<String, dynamic>>(
      '/teachers/',
      data: {
        'institution_id': institutionId,
        'first_name': 'Prof',
        'last_name': 'Emploi$uniqueSuffix',
        'phone': '+224621333444',
        'academic_unit_ids': [academicUnitId],
      },
      options: adminAuthHeader,
    );
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/institutions/$institutionId', options: adminAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('school_administrator creates a subject and a time slot, shown on the class timetable', (
    tester,
  ) async {
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

    // Institution already exists (seeded in setUpAll) -> straight to the
    // management menu, not the create form.
    expect(find.text('Gestion'), findsOneWidget);

    // --- Subject ---
    await _tapAndSettle(tester, find.text('Matières'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la matière'), subjectName);
    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer la matière'));

    expect(find.text(subjectName), findsOneWidget);

    await _pageBackAndSettle(tester);
    expect(find.text('Gestion'), findsOneWidget);

    // --- Time slot, reached via the class list's schedule icon ---
    await _tapAndSettle(tester, find.text('Classes / départements'));

    expect(find.text(unitName), findsOneWidget);
    await _tapAndSettle(tester, find.byTooltip('Emploi du temps'));

    expect(find.text('Emploi du temps'), findsOneWidget);
    expect(find.text('Aucun créneau enregistré pour le moment.'), findsOneWidget);

    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.runAsync(() async {
      // subjectsProvider + teachersProvider for the two dropdowns.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Subject>), subjectName);
    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Teacher>), teacherFullName);

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Choisir').first);
    await tester.tap(find.widgetWithText(InkWell, 'Choisir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'Choisir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer le créneau'));

    expect(find.text('Lundi'), findsOneWidget);
    expect(find.text(subjectName), findsOneWidget);
    expect(find.text(teacherFullName), findsOneWidget);
  });
}
