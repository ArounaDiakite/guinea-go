// Real end-to-end test against the live local backend - no HTTP
// mocking. Logs in as a pre-provisioned fixture company_owner account
// (company_owner_e2e_fixture@test.com, role flipped directly in
// MongoDB once - there's no seeded company_owner and register-partner
// requires admin activation, same bootstrapping gap noted in
// transport_driver_test.dart) with NO company yet, then drives every
// real screen in the "Ma compagnie" section: creates the company,
// then a bus (+ seat generation), a driver, a route, a schedule and
// finally a trip tying them all together. Ends by calling the real
// passenger-facing TransportRepository.searchTrips (the exact method
// SearchScreen/ResultsScreen use) to confirm the new trip is
// discoverable exactly the way a passenger would find it.
//
// Date/time pickers are confirmed via their default "OK" button
// without changing the pre-filled value (each form's own initialDate/
// initialTime is already a sensible default - e.g. tomorrow for a
// trip's travel date) - calendar/clock grid taps would be far more
// brittle across Flutter versions for no real coverage gain, since
// the backend's date/time handling is validated separately.
//
// Every navigation that lands on a screen with a FutureProvider-backed
// dropdown goes through _waitForAsyncData rather than a bare
// pumpAndSettle(): pumpAndSettle's frame pumping fast-forwards this
// binding's fake clock straight past Dio's real timeout for whatever
// request is still in flight, which would permanently wedge that
// autoDispose FutureProvider in an error state (it doesn't self-retry)
// - seen firsthand while writing this test, not a hypothetical.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guinea_go/app.dart';
import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/transport/data/transport_repository.dart';
import 'package:guinea_go/features/transport/models/city.dart';
import 'package:guinea_go/features/transport/models/country.dart';
import 'package:guinea_go/features/transport/models/managed_bus.dart';
import 'package:guinea_go/features/transport/models/managed_driver.dart';
import 'package:guinea_go/features/transport/models/managed_route.dart';
import 'package:guinea_go/features/transport/models/managed_schedule.dart';
import 'package:guinea_go/features/transport/models/station.dart';

const _ownerEmail = 'company_owner_e2e_fixture@test.com';
const _ownerPassword = 'TestPass123!';

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

/// Confirms a Material date/time picker dialog via its own "OK"
/// button, keeping whatever initialDate/initialTime the form already
/// pre-filled.
Future<void> _confirmPickerDialog(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownItem(WidgetTester tester, Finder dropdownFinder, String itemText) async {
  await tester.ensureVisible(dropdownFinder);
  await tester.tap(dropdownFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

/// Every tap that triggers real async work (navigation to a screen
/// that immediately fetches, or a form submit) goes through here -
/// never a bare tap() followed by a bare pumpAndSettle(), for the same
/// fake-clock-vs-real-network reason as _waitForAsyncData.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder, {Duration wait = const Duration(seconds: 2)}) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future.delayed(wait);
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
    await tester.pump(); // process the pop navigation back to the list
    await Future.delayed(const Duration(seconds: 2)); // list's post-invalidate re-fetch
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

/// A freshly-mounted screen with its own FutureProvider-backed dropdown
/// (countries/cities, stations/currencies, routes, ...) needs real
/// wall-clock time to pass *before* any pumpAndSettle() runs, so the
/// whole navigation-then-fetch cascade - including the tap that
/// triggers it, if any - is kept inside one continuous runAsync zone.
/// Never a bare tap()/pumpAndSettle() first.
Future<void> _waitForAsyncData(
  WidgetTester tester, {
  Finder? tapFirst,
  Duration wait = const Duration(seconds: 3),
}) async {
  await tester.runAsync(() async {
    if (tapFirst != null) await tester.tap(tapFirst);
    await tester.pump(); // process the navigation transition, mount the new screen
    await Future.delayed(wait);
    await tester.pump(); // render with the now-resolved data
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
  final companyName = 'E2E Transport $uniqueSuffix';
  final driverFullName = 'E2E Driver$uniqueSuffix';
  final routeName = 'Conakry - Kankan E2E $uniqueSuffix';

  testWidgets(
    'company_owner creates a company, bus, driver, route, schedule and trip - '
    'the trip then shows up in passenger search',
    (tester) async {
      final authContainer = ProviderContainer();
      await tester.runAsync(() async {
        await authContainer.read(authControllerProvider.notifier).login(
          email: _ownerEmail,
          password: _ownerPassword,
        );
      });
      authContainer.dispose();

      // Makes this test idempotent across reruns: this fixture account
      // is reused (not uniquely created per run, unlike the rest of
      // this suite) specifically so the create-company form's empty
      // state is exercised every time - so any company left over from
      // a previous run is deleted (soft-delete, excluded from
      // subsequent GET /companies/ queries) before driving the UI.
      await tester.runAsync(() async {
        final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final loginResponse = await setupDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': _ownerEmail, 'password': _ownerPassword},
        );
        final token = loginResponse.data!['access_token'] as String;
        final userId = loginResponse.data!['user']['id'] as String;
        final authHeader = Options(headers: {'Authorization': 'Bearer $token'});

        final existing = await setupDio.get<List<dynamic>>(
          '/companies/',
          queryParameters: {'owner_id': userId, 'limit': 10},
          options: authHeader,
        );
        for (final company in existing.data!.cast<Map<String, dynamic>>()) {
          await setupDio.delete<void>('/companies/${company['id']}', options: authHeader);
        }
        setupDio.close();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // connectivity + session restore + splash hold
        await tester.pump(); // go_router redirects to /hub/company
        await Future.delayed(const Duration(seconds: 2)); // myCompanyProvider resolves to null
        await tester.pump(); // CreateCompanyForm mounts, kicks off countries/cities
        await Future.delayed(const Duration(seconds: 3));
        await tester.pump();
      });
      await tester.pumpAndSettle();

      // Landed on the company_owner's own nav tab, no company yet ->
      // the create-company form.
      expect(find.text('Ma compagnie'), findsWidgets);
      expect(find.text('Créez votre compagnie'), findsOneWidget);
      expect(find.text('Transport'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la compagnie'), companyName);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone'),
        '+224621000$uniqueSuffix'.substring(0, 16),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email professionnel'),
        'e2e_owner_$uniqueSuffix@test.com',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Adresse'), 'Kaloum, Conakry');

      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Country>), 'Guinea');
      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<City>), 'Conakry');

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer ma compagnie'));

      // Company created - now on the management menu.
      expect(find.text(companyName), findsOneWidget);
      expect(find.text('Bus'), findsOneWidget);

      // --- Bus (no FutureProvider-backed dropdown on this form) ---
      await _tapAndSettle(tester, find.text('Bus'));
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Numéro d\'immatriculation'), 'RC-E2E-$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Numéro de flotte'), 'F-E2E-$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Marque'), 'Mercedes');
      await tester.enterText(find.widgetWithText(TextFormField, 'Modèle'), 'Sprinter');
      // Année / Capacité (sièges) already carry sensible default text.

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Ajouter le bus'));

      expect(find.text('Mercedes Sprinter'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Générer les sièges'));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(find.text('Sièges générés.'), findsOneWidget);

      // The SnackBar is scoped to the app's single root ScaffoldMessenger,
      // so it visually persists across navigation until its own ~4s
      // timer dismisses it - a duration-pump (fake-clock, driving its
      // AnimationController/Timer forward deterministically, no real
      // wall-clock wait needed) clears it before it can go on absorbing
      // taps in the same screen region a FAB occupies on the next screen.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Driver (no FutureProvider-backed dropdown on this form) ---
      await _tapAndSettle(tester, find.text('Chauffeurs'));
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'E2E');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'Driver$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'e2e_driver_$uniqueSuffix@test.com');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Téléphone'),
        '+224622000$uniqueSuffix'.substring(0, 16),
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Conakry');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'TestPass123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Matricule employé'), 'EMP-E2E-$uniqueSuffix');
      await tester.enterText(find.widgetWithText(TextFormField, 'Numéro de permis'), 'LIC-E2E-$uniqueSuffix');

      await tester.ensureVisible(find.text('Date de naissance'));
      await tester.tap(find.text('Choisir une date').first);
      await _confirmPickerDialog(tester);

      await tester.ensureVisible(find.text('Expiration du permis'));
      await tester.tap(find.text('Choisir une date').first);
      await _confirmPickerDialog(tester);

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Ajouter le chauffeur'));

      expect(find.text(driverFullName), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Route (station/currency dropdowns are FutureProvider-backed) ---
      await _tapAndSettle(tester, find.text('Routes'));
      await _waitForAsyncData(tester, tapFirst: find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la route'), routeName);
      await tester.enterText(find.widgetWithText(TextFormField, 'Code de la route'), 'E2E-$uniqueSuffix');

      final stationDropdown = find.byType(DropdownButtonFormField<Station>);
      await _selectDropdownItem(tester, stationDropdown.first, 'Conakry Central Bus Station');
      await _selectDropdownItem(tester, stationDropdown.last, 'Kankan Gare Routiere');

      await tester.enterText(find.widgetWithText(TextFormField, 'Distance (km)'), '620');
      await tester.enterText(find.widgetWithText(TextFormField, 'Durée (min)'), '540');
      await tester.enterText(find.widgetWithText(TextFormField, 'Prix de base'), '225000');

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer la route'));

      expect(find.text(routeName), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Schedule (route dropdown is FutureProvider-backed) ---
      await _waitForAsyncData(tester, tapFirst: find.text('Horaires & trajets'));
      await _waitForAsyncData(tester, tapFirst: find.byType(FloatingActionButton));

      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<ManagedRoute>), routeName);

      await tester.tap(find.text('Choisir une heure').first);
      await _confirmPickerDialog(tester);

      await tester.tap(find.text('Lun'));
      await tester.pumpAndSettle();

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer l\'horaire'));

      // Back on the Trips screen, Horaires tab, showing the new schedule.
      expect(find.text(routeName), findsOneWidget);

      // --- Trip (route/schedule/bus/driver dropdowns are FutureProvider-backed) ---
      await _waitForAsyncData(tester, tapFirst: find.text('Trajets'));
      await _waitForAsyncData(tester, tapFirst: find.byType(FloatingActionButton));

      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<ManagedRoute>), routeName);
      await _waitForAsyncData(tester, wait: const Duration(seconds: 1));
      // The schedule dropdown now offers the one just created, labeled
      // by its departure time (confirmed via OK above -> 08:00 default).
      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<ManagedSchedule>), '08:00');
      await _selectDropdownItem(
        tester,
        find.byType(DropdownButtonFormField<ManagedBus>),
        'Mercedes Sprinter (RC-E2E-$uniqueSuffix)',
      );
      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<ManagedDriver>), driverFullName);

      // Unlike the driver form's nullable dates, _travelDate already
      // defaults to tomorrow and is shown as a formatted date, not a
      // "Choisir une date" placeholder - tap the field via its icon.
      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await _confirmPickerDialog(tester);

      final travelDate = DateTime.now().add(const Duration(days: 1));
      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer le trajet'));

      // Back on the Trips screen, Trajets tab, showing the new trip.
      expect(find.text(routeName), findsWidgets);

      // --- Passenger-side discoverability ---
      // The exact call SearchScreen/ResultsScreen make - confirms the
      // trip just created through the company_owner UI is genuinely
      // reachable through the ordinary passenger search flow, not just
      // present in the company's own trip list.
      await tester.runAsync(() async {
        final searchDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
        final citiesResponse = await searchDio.get<List<dynamic>>('/cities/');
        final cities = citiesResponse.data!.cast<Map<String, dynamic>>();
        final conakry = cities.firstWhere((city) => city['name'] == 'Conakry');
        final kankan = cities.firstWhere((city) => city['name'] == 'Kankan');
        searchDio.close();

        final repository = TransportRepository(Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)));
        final results = await repository.searchTrips(
          originCityId: conakry['id'] as String,
          destinationCityId: kankan['id'] as String,
          date: travelDate,
        );

        final match = results.where((result) => result.company.name == companyName);
        expect(match.length, 1, reason: 'the newly created trip should appear exactly once in passenger search');
      });
    },
  );
}
