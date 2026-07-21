// Real end-to-end test against the live local backend - no HTTP
// mocking. Covers Step 3 of the Education module: whole-class
// attendance submission for one time slot + date, grade entry, and
// the report card's backend-computed weighted average.
//
// Builds its own throwaway institution/class/teacher/subject/timeslot/
// students fixture fresh in setUpAll via the API - institution
// creation through the real UI is already covered end-to-end by
// education_school_setup_test.dart, and subject/timeslot creation by
// education_schedule_test.dart, so this test seeds all of that
// directly and focuses on what's new in this step. Uses a THIRD
// dedicated school_administrator_grades_e2e_fixture account, since a
// school_administrator can only ever administer one institution and
// sharing either of the other two fixtures would race over that 1:1
// slot whenever multiple test files run concurrently (flutter test's
// default).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/widgets/app_card.dart';
import 'package:guinea_go/features/education/models/attendance.dart';
import 'package:guinea_go/features/education/models/subject.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';

const _adminEmail = 'school_administrator_grades_e2e_fixture@test.com';
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
  final unitName = 'CM2 E2E $uniqueSuffix';
  final subjectName = 'Sciences E2E $uniqueSuffix';
  final firstStudentFullName = 'Aissatou Diallo$uniqueSuffix';
  final secondStudentFullName = 'Mamadou Bah$uniqueSuffix';

  late Options adminAuthHeader;
  late String institutionId;
  late String timeSlotId;
  late String firstStudentId;
  late String secondStudentId;

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
        'name': 'École Notes E2E $uniqueSuffix',
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
      data: {'institution_id': institutionId, 'name': unitName, 'level': 'CM2'},
      options: adminAuthHeader,
    );
    final academicUnitId = unitResponse.data!['id'] as String;

    final teacherResponse = await setupDio.post<Map<String, dynamic>>(
      '/teachers/',
      data: {
        'institution_id': institutionId,
        'first_name': 'Prof',
        'last_name': 'Notes$uniqueSuffix',
        'phone': '+224621444555',
        'academic_unit_ids': [academicUnitId],
      },
      options: adminAuthHeader,
    );
    final teacherId = teacherResponse.data!['id'] as String;

    final subjectResponse = await setupDio.post<Map<String, dynamic>>(
      '/subjects/',
      data: {'institution_id': institutionId, 'name': subjectName},
      options: adminAuthHeader,
    );
    final subjectId = subjectResponse.data!['id'] as String;

    final timeSlotResponse = await setupDio.post<Map<String, dynamic>>(
      '/timeslots/',
      data: {
        'academic_unit_id': academicUnitId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'day_of_week': 'MONDAY',
        'start_time': '08:00:00',
        'end_time': '09:00:00',
      },
      options: adminAuthHeader,
    );
    timeSlotId = timeSlotResponse.data!['id'] as String;

    final firstStudentResponse = await setupDio.post<Map<String, dynamic>>(
      '/students/',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': academicUnitId,
        'first_name': 'Aissatou',
        'last_name': 'Diallo$uniqueSuffix',
      },
      options: adminAuthHeader,
    );
    firstStudentId = firstStudentResponse.data!['id'] as String;

    final secondStudentResponse = await setupDio.post<Map<String, dynamic>>(
      '/students/',
      data: {
        'institution_id': institutionId,
        'academic_unit_id': academicUnitId,
        'first_name': 'Mamadou',
        'last_name': 'Bah$uniqueSuffix',
      },
      options: adminAuthHeader,
    );
    secondStudentId = secondStudentResponse.data!['id'] as String;
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/institutions/$institutionId', options: adminAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('school_administrator submits attendance, enters a grade, and sees the report card average', (
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

    expect(find.text('Gestion'), findsOneWidget);

    // --- Attendance: whole class, one time slot + date ---
    await _tapAndSettle(tester, find.text('Classes / départements'));
    expect(find.text(unitName), findsOneWidget);
    await _tapAndSettle(tester, find.byTooltip('Emploi du temps'));

    expect(find.text(subjectName), findsOneWidget);
    await _tapAndSettle(tester, find.byTooltip('Présences'));

    expect(find.text('Présences'), findsOneWidget);

    await tester.runAsync(() async {
      // studentsProvider real fetch.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text(firstStudentFullName), findsOneWidget);
    expect(find.text(secondStudentFullName), findsOneWidget);

    // Mark the first student absent - the second stays on the default
    // "Présent", exercising the whole-class-at-once submission with a
    // genuine mix of statuses rather than every student trivially
    // matching the default.
    await tester.ensureVisible(find.text(firstStudentFullName));
    await tester.pumpAndSettle();
    final firstStudentCard = find.ancestor(of: find.text(firstStudentFullName), matching: find.byType(AppCard));
    await tester.tap(
      find.descendant(of: firstStudentCard, matching: find.byType(DropdownButton<AttendanceStatus>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Absent'));
    await tester.pumpAndSettle();

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Enregistrer les présences'));

    // Back on the schedule screen.
    expect(find.text('Emploi du temps'), findsOneWidget);

    // Verify directly against the backend - the real thing under test,
    // independent of whatever the UI happens to still be showing.
    await tester.runAsync(() async {
      final firstCheck = await setupDio.get<List<dynamic>>(
        '/students/$firstStudentId/attendance',
        options: adminAuthHeader,
      );
      final firstRecord = firstCheck.data!.cast<Map<String, dynamic>>().firstWhere(
        (record) => record['timeslot_id'] == timeSlotId,
      );
      expect(firstRecord['status'], 'absent');

      final secondCheck = await setupDio.get<List<dynamic>>(
        '/students/$secondStudentId/attendance',
        options: adminAuthHeader,
      );
      final secondRecord = secondCheck.data!.cast<Map<String, dynamic>>().firstWhere(
        (record) => record['timeslot_id'] == timeSlotId,
      );
      expect(secondRecord['status'], 'present');
    });

    // --- Grade entry ---
    await _pageBackAndSettle(tester);
    expect(find.text(unitName), findsOneWidget);
    await _pageBackAndSettle(tester);
    expect(find.text('Gestion'), findsOneWidget);

    await _tapAndSettle(tester, find.text('Élèves'));
    expect(find.text(firstStudentFullName), findsOneWidget);

    await _tapAndSettle(tester, find.byTooltip('Notes').first);

    expect(find.text('Notes'), findsOneWidget);
    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.runAsync(() async {
      // subjectsProvider fetch for the subject dropdown.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Subject>), subjectName);

    await tester.enterText(find.widgetWithText(TextFormField, 'Note / 20'), '15');
    await tester.enterText(find.widgetWithText(TextFormField, 'Coefficient'), '2');

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Ajouter la note'));

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text(subjectName), findsOneWidget);
    expect(find.text('15/20'), findsOneWidget);

    // --- Report card: backend-computed weighted average ---
    await _tapAndSettle(tester, find.byTooltip('Bulletin'));

    expect(find.text('Bulletin'), findsOneWidget);

    await tester.runAsync(() async {
      // reportCardProvider real fetch.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text(subjectName), findsOneWidget);
    // A single 15/20 grade in this subject and this period - both the
    // subject average and the overall average (weighted by coefficient
    // mass, but there's only one grade so it's just the grade itself)
    // read exactly "15.00/20".
    expect(find.text('15.00/20'), findsNWidgets(2));
  });
}
