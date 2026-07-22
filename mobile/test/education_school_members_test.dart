// Real end-to-end test against the live local backend - no HTTP
// mocking. Covers the teacher/student self-registration flow: a
// school_administrator creates a Teacher/Student profile (which gets a
// server-generated invite_code), the invitee self-registers through
// the real RegisterSchoolMemberScreen using that code, lands on their
// role's own hub tab, and from there a teacher submits attendance for
// their own time slot (accepted) and is blocked from a colleague's
// slot (rejected, both by the UI hiding the control and by the
// backend itself), while a student only ever sees read-only data.
// Reusing an already-claimed invite code is rejected too.
//
// Uses a dedicated school_administrator_school_members_e2e_fixture
// account (same pattern as education_attendance_grades_test.dart's own
// dedicated fixture - a school_administrator can only ever administer
// one institution, so each education test file that needs its own
// gets its own account to avoid racing over that 1:1 slot when
// `flutter test`'s default concurrency runs files in parallel).
// Everything else (institution, class, subject, teachers, student,
// time slots, and the two invitee accounts created during the test
// itself) is fresh per run, deleted/rebuilt in setUpAll and torn down
// in tearDownAll.
//
// Every tap that triggers a real HTTP request (directly, or via
// navigation to a screen whose build() watches a FutureProvider) stays
// inside the same runAsync() block as its wait, with an extra
// pump-then-wait-again stage wherever a screen's data: branch mounts a
// child that watches a further, nested provider - see
// TeacherHomeScreen (myTeacherProfileProvider -> _AcademicUnitCard's
// academicUnitDetailProvider) below.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/network/token_storage.dart';

const _adminEmail = 'school_administrator_school_members_e2e_fixture@test.com';
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

/// Forces a genuine unmount before mounting the same widget type again
/// (GuineaGoApp, each time with a different initialLocation override) -
/// see transport_my_bookings_test.dart's header comment for why a bare
/// second pumpWidget call of the same widget type only *updates* the
/// existing element tree instead of remounting it.
Future<void> _remount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(widget);
  await tester.pump();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder, {Duration wait = const Duration(seconds: 3)}) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future.delayed(wait);
    await tester.pump();
    await Future.delayed(wait);
    await tester.pump();
    await Future.delayed(wait);
  });
  await tester.pumpAndSettle();
}

Widget _appAt(String location) {
  return ProviderScope(
    overrides: [initialLocationProvider.overrideWithValue(location)],
    child: const GuineaGoApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  final unitName = 'CM1 SM E2E $uniqueSuffix';
  final subjectName = 'Histoire SM E2E $uniqueSuffix';
  final studentFullName = 'Fatoumata Camara$uniqueSuffix';

  late Options adminAuthHeader;
  late String institutionId;
  late String ownTeacherId;
  late String ownTeacherInviteCode;
  late String otherTeacherId;
  late String studentId;
  late String studentInviteCode;
  late String ownTimeSlotId;
  late String otherTimeSlotId;

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
        'name': 'École School Members E2E $uniqueSuffix',
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

    final subjectResponse = await setupDio.post<Map<String, dynamic>>(
      '/subjects/',
      data: {'institution_id': institutionId, 'name': subjectName},
      options: adminAuthHeader,
    );
    final subjectId = subjectResponse.data!['id'] as String;

    final ownTeacherResponse = await setupDio.post<Map<String, dynamic>>(
      '/teachers/',
      data: {
        'institution_id': institutionId,
        'first_name': 'Own',
        'last_name': 'Teacher$uniqueSuffix',
        'phone': '+224621555${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 3)}',
        'academic_unit_ids': [academicUnitId],
      },
      options: adminAuthHeader,
    );
    ownTeacherId = ownTeacherResponse.data!['id'] as String;
    ownTeacherInviteCode = ownTeacherResponse.data!['invite_code'] as String;

    final otherTeacherResponse = await setupDio.post<Map<String, dynamic>>(
      '/teachers/',
      data: {
        'institution_id': institutionId,
        'first_name': 'Other',
        'last_name': 'Teacher$uniqueSuffix',
        'phone': '+224621556${uniqueSuffix.toString().substring(uniqueSuffix.toString().length - 3)}',
        'academic_unit_ids': [academicUnitId],
      },
      options: adminAuthHeader,
    );
    otherTeacherId = otherTeacherResponse.data!['id'] as String;

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
    studentInviteCode = studentResponse.data!['invite_code'] as String;

    final ownTimeSlotResponse = await setupDio.post<Map<String, dynamic>>(
      '/timeslots/',
      data: {
        'academic_unit_id': academicUnitId,
        'subject_id': subjectId,
        'teacher_id': ownTeacherId,
        'day_of_week': 'MONDAY',
        'start_time': '08:00:00',
        'end_time': '09:00:00',
      },
      options: adminAuthHeader,
    );
    ownTimeSlotId = ownTimeSlotResponse.data!['id'] as String;

    final otherTimeSlotResponse = await setupDio.post<Map<String, dynamic>>(
      '/timeslots/',
      data: {
        'academic_unit_id': academicUnitId,
        'subject_id': subjectId,
        'teacher_id': otherTeacherId,
        'day_of_week': 'TUESDAY',
        'start_time': '08:00:00',
        'end_time': '09:00:00',
      },
      options: adminAuthHeader,
    );
    otherTimeSlotId = otherTimeSlotResponse.data!['id'] as String;
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/institutions/$institutionId', options: adminAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets(
    'teacher self-registers, submits attendance for their own slot, is rejected on another; '
    'reused code is rejected; student self-registers and only sees read-only data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // --- Teacher self-registration via invite code ---
      final teacherEmail = 'teacher_sm_e2e_$uniqueSuffix@test.com';
      const teacherPassword = 'TestPass123!';

      await TokenStorage.clear();
      await tester.runAsync(() async {
        await tester.pumpWidget(_appAt('/register-school-member'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Code d\'invitation'), ownTeacherInviteCode);
      await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Own');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Teacher$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), teacherEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224622000099');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), teacherPassword);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Activer mon compte'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // register-school-member + navigate to /hub/teacher
        await tester.pump(); // myTeacherProfileProvider resolves, mounts _AcademicUnitCard
        await Future.delayed(const Duration(seconds: 3)); // academicUnitDetailProvider fetch
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Mes classes'), findsOneWidget);
      expect(find.text(unitName), findsOneWidget);

      // --- Reused invite code is rejected ---
      await tester.runAsync(() async {
        await _remount(tester, _appAt('/register-school-member'));
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Code d\'invitation'), ownTeacherInviteCode);
      await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Dup');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Licate$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'dup_sm_e2e_$uniqueSuffix@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224622000098');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'TestPass123!');

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Activer mon compte'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();

      expect(find.text('This invite code has already been used.'), findsOneWidget);

      // --- Log the teacher back in for the attendance flow ---
      await TokenStorage.clear();
      await tester.runAsync(() async {
        await _remount(tester, _appAt('/login'));
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), teacherEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), teacherPassword);
      late String teacherToken;
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Se connecter'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // login + navigate to /hub/teacher
        await tester.pump(); // myTeacherProfileProvider resolves, mounts _AcademicUnitCard
        await Future.delayed(const Duration(seconds: 3)); // academicUnitDetailProvider fetch
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
        teacherToken = (await TokenStorage.readAccessToken())!;
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Mes classes'), findsOneWidget);

      // --- Open the class: TabBarView builds every child up front
      // (not lazily on first visit), so both the roster's and the
      // schedule tab's fetches start together right here, not when the
      // "Emploi du temps" tab is later tapped - both have to actually
      // finish inside this same real-time window (see the note atop
      // this file: once a FutureProvider's fetch is left pending when a
      // bare pumpAndSettle() takes over, it can wedge into a permanent
      // error state that no amount of waiting afterwards recovers). ---
      await tester.runAsync(() async {
        await tester.tap(find.text(unitName));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 4));
      });
      await tester.pumpAndSettle();

      expect(find.text('Élèves'), findsOneWidget);
      expect(find.text(studentFullName), findsOneWidget);

      // A single zero-duration pump() doesn't drive the TabController's
      // switch animation to completion (the second tab's page never
      // actually gets built, and the "Élèves" roster stays on screen) -
      // several small real-duration pumps let the transition actually
      // finish before the schedule tab's own fetch even starts.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(Tab, 'Emploi du temps'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await Future.delayed(const Duration(seconds: 4));
      });
      await tester.pump();

      expect(find.text(subjectName), findsNWidgets(2));

      // Only the teacher's own (Monday) slot carries the attendance
      // shortcut - the colleague's (Tuesday) one has none.
      expect(find.byTooltip('Saisir les présences'), findsOneWidget);

      // --- Submit attendance for the own slot ---
      await _tapAndSettle(tester, find.byTooltip('Saisir les présences'), wait: const Duration(seconds: 3));
      expect(find.text('Présences'), findsOneWidget);
      expect(find.text(studentFullName), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer les présences'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();

      // Verify directly against the backend.
      await tester.runAsync(() async {
        final check = await setupDio.get<List<dynamic>>(
          '/students/$studentId/attendance',
          options: adminAuthHeader,
        );
        final record = check.data!.cast<Map<String, dynamic>>().firstWhere(
          (r) => r['timeslot_id'] == ownTimeSlotId,
        );
        expect(record['status'], 'present');
      });

      // --- Attempting the colleague's slot is rejected server-side too ---
      await tester.runAsync(() async {
        final teacherDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        try {
          await teacherDio.post<void>(
            '/timeslots/$otherTimeSlotId/attendance',
            data: {
              'date': '2026-07-20',
              'entries': [
                {'student_id': studentId, 'status': 'present'},
              ],
            },
            options: Options(headers: {'Authorization': 'Bearer $teacherToken'}),
          );
          fail('expected a 403 for a time slot not assigned to this teacher');
        } on DioException catch (error) {
          expect(error.response?.statusCode, 403);
        } finally {
          teacherDio.close();
        }
      });

      // --- Student self-registration via invite code ---
      await TokenStorage.clear();
      final studentEmail = 'student_sm_e2e_$uniqueSuffix@test.com';
      const studentPassword = 'TestPass123!';

      await tester.runAsync(() async {
        await _remount(tester, _appAt('/register-school-member'));
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Code d\'invitation'), studentInviteCode);
      await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'Fatoumata');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Camara$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), studentEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224622000097');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), studentPassword);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Activer mon compte'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // register-school-member + navigate to /hub/student
        await tester.pump(); // myStudentProfileProvider resolves
        await Future.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Mon espace'), findsOneWidget);
      expect(find.text(studentFullName), findsOneWidget);

      // --- Read-only schedule ---
      await _tapAndSettle(tester, find.text('Emploi du temps'), wait: const Duration(seconds: 3));
      expect(find.text(subjectName), findsNWidgets(2));
      // No attendance-entry control anywhere on the student's schedule.
      expect(find.byTooltip('Saisir les présences'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Read-only fees (no "apply" FAB) ---
      await _tapAndSettle(tester, find.text('Frais de scolarité'), wait: const Duration(seconds: 3));
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Read-only attendance history ---
      await _tapAndSettle(tester, find.text('Présences'), wait: const Duration(seconds: 3));
      expect(find.text('Présent'), findsOneWidget);
    },
  );
}
