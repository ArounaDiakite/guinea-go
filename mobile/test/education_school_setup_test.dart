// Real end-to-end test against the live local backend - no HTTP
// mocking. Logs in as the pre-provisioned school_administrator_e2e_
// fixture account (role flipped directly in MongoDB once, same
// bootstrapping gap as company_owner_e2e_fixture/store_manager_e2e_
// fixture - register-institution's atomic account+institution flow
// isn't wired into the mobile UI yet, and there's no seeded school_
// administrator either). Unlike company_owner_e2e_fixture (which the
// existing transport test resets to "no company yet" itself), this
// fixture's whole point is to always start from "no institution yet" -
// setUpAll deletes any institution left over from a previous run so
// the create-institution form's empty state is exercised every time.
//
// Drives every real screen in "Mon établissement": creates the
// institution (private type only), then a class, a teacher assigned to
// it, and a student enrolled in it.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/models/city.dart';
import 'package:guinea_go/core/models/country.dart';
import 'package:guinea_go/features/education/models/academic_unit.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';

const _adminEmail = 'school_administrator_e2e_fixture@test.com';
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

/// Same care level as _tapAndSettle - popping back to a screen still
/// mounted underneath doesn't need a new fetch here (its provider's
/// value is already cached), but the pop transition itself still needs
/// real time to process before a bare pumpAndSettle() can be trusted.
Future<void> _pageBackAndSettle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pageBack();
    await tester.pump();
    await Future.delayed(const Duration(seconds: 1));
  });
  await tester.pumpAndSettle();
}

/// A create-form's submit button: on success it invalidates the list
/// provider *and* pops back to the list screen, which then re-fetches.
/// That pop and re-fetch only get processed on a *later* pump - so an
/// extra pump+real-delay is needed after the submit's own wait, still
/// inside the same runAsync zone, before it's safe to fall through to
/// the outer pumpAndSettle().
Future<void> _submitAndSettle(
  WidgetTester tester,
  Finder submitButton, {
  Duration wait = const Duration(seconds: 4),
}) async {
  await tester.ensureVisible(submitButton);
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
  // scrollUntilVisible (not ensureVisible) - ensureVisible only checks
  // RenderObject bounds and can still leave a target un-hit-testable at
  // a narrow phone width, where a taller form means small differences
  // in "visible enough" matter more than they do at the wide default
  // test surface.
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
  final institutionName = 'École E2E $uniqueSuffix';
  final unitName = 'CM2 E2E $uniqueSuffix';
  final teacherFirstName = 'Prof';
  final teacherLastName = 'E2E$uniqueSuffix';
  final studentFirstName = 'Eleve';
  final studentLastName = 'E2E$uniqueSuffix';

  late Options adminAuthHeader;

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
    } catch (_) {
      // No institution yet - already the state this test wants to start from.
    }
  });

  tearDownAll(() async {
    try {
      final existing = await setupDio.get<Map<String, dynamic>>('/institutions/me', options: adminAuthHeader);
      await setupDio.delete<void>('/institutions/${existing.data!['id']}', options: adminAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('school_administrator creates an institution, a class, a teacher and a student', (tester) async {
    // Same real-phone width as the other E2E tests (still the axis that
    // matters for overflow coverage) - a bit taller than the usual 800
    // since the create-institution form's extra "public vs private"
    // info banner pushes its Country dropdown just past the fold at
    // exactly 800, which ensureVisible doesn't reliably recover from.
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
      await tester.pump(); // go_router redirects straight to /hub/school (landingRouteForRole)
      await Future.delayed(const Duration(seconds: 2)); // myInstitutionProvider resolves to null
      // _CreateInstitutionForm only mounts - and only then starts its
      // own GET /countries/ + GET /cities/ - once myInstitutionProvider
      // resolves and the tree rebuilds past the loading state. Pump
      // here, still inside runAsync, so those fetches are created in
      // the real zone too.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    // No institution yet -> straight to the create form's empty state.
    expect(find.text('Créez votre établissement'), findsOneWidget);
    expect(find.text('Gestion'), findsNothing);

    // --- Institution (private type only) ---
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom de l\'établissement'), institutionName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Adresse'), 'Kaloum, Conakry');

    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Country>), 'Guinea');
    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<City>), 'Conakry');

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer mon établissement'));
      await tester.pump();
      // Real POST /institutions/, then ref.invalidate(myInstitutionProvider)
      // fires a second real GET /institutions/me before _InstitutionMenu
      // can render - two sequential round trips, not one.
      await Future.delayed(const Duration(seconds: 5));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text(institutionName), findsOneWidget);
    expect(find.text('Gestion'), findsOneWidget);

    // --- Academic unit ---
    await _tapAndSettle(tester, find.text('Classes / départements'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom (ex: CM2 A, Terminale S2, Génie Civil)'),
      unitName,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Niveau (ex: CE1, Seconde, L1)'), 'CM2');

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer'));

    expect(find.text(unitName), findsOneWidget);

    await _pageBackAndSettle(tester);
    expect(find.text('Gestion'), findsOneWidget);

    // --- Teacher, assigned to the new class ---
    await _tapAndSettle(tester, find.text('Enseignants'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), teacherFirstName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), teacherLastName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224621222333');

    await tester.runAsync(() async {
      // Loads academicUnitsProvider for the chip row.
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, unitName));
    await tester.tap(find.widgetWithText(FilterChip, unitName));
    await tester.pumpAndSettle();

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Ajouter l\'enseignant'));

    expect(find.text('$teacherFirstName $teacherLastName'), findsOneWidget);

    await _pageBackAndSettle(tester);
    expect(find.text('Gestion'), findsOneWidget);

    // --- Student, enrolled in the new class ---
    await _tapAndSettle(tester, find.text('Élèves'));
    await _tapAndSettle(tester, find.byType(FloatingActionButton));

    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), studentFirstName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), studentLastName);

    await tester.runAsync(() async {
      await Future.delayed(const Duration(seconds: 2)); // academicUnitsProvider for the dropdown
    });
    await tester.pumpAndSettle();
    await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<AcademicUnit>), '$unitName (CM2)');

    await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Inscrire l\'élève'));

    expect(find.text('$studentFirstName $studentLastName'), findsOneWidget);

    // Filtering the student list by the new class should still show them.
    await tester.ensureVisible(find.widgetWithText(FilterChip, unitName));
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilterChip, unitName));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('$studentFirstName $studentLastName'), findsOneWidget);
  });
}
