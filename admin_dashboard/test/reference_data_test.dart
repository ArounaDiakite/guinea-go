// Real end-to-end test against the live local backend - no HTTP
// mocking. Countries/cities/currencies have no PUT/DELETE endpoint at
// all (see CLAUDE.md's "Données de référence" section) - anything
// created here is permanent, so every record uses a code/name unique
// to this run (a millisecond-timestamp suffix) rather than a fixed
// throwaway value, to stay safe across repeated runs without ever
// colliding with a previous run's leftovers or a real seeded country.
//
// Creates a currency, then a country referencing it by code, then a
// city referencing that country - the same dependency chain the
// backend itself enforces (POST /countries 400s if currency_code
// doesn't exist yet) - through the real dialogs on each tab, and
// confirms each shows up in its list afterward.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_dashboard/app.dart';
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

Future<void> _submitDialog(WidgetTester tester, String buttonLabel) async {
  await tester.runAsync(() async {
    await tester.tap(find.widgetWithText(ElevatedButton, buttonLabel));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final uniqueSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  final currencyCode = 'TC$uniqueSuffix';
  final currencyName = 'Test Currency E2E $uniqueSuffix';
  final countryCode = 'TZ$uniqueSuffix';
  final countryName = 'Test Country E2E $uniqueSuffix';
  final cityName = 'Test City E2E $uniqueSuffix';

  testWidgets('creating a currency, then a country, then a city all show up in their lists', (tester) async {
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
      await tester.tap(find.text('Données de référence'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Données de référence'), findsOneWidget);

    // --- Devises tab (default) ---
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Ajouter une devise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Code (ex. GNF)'), currencyCode);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), currencyName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Symbole'), 'T\$');

    await _submitDialog(tester, 'Créer');

    expect(find.textContaining(currencyName), findsOneWidget);

    // --- Pays tab ---
    await tester.tap(find.text('Pays'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Ajouter un pays'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2)); // dialog's own currenciesProvider fetch
    });
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Code ISO (ex. GN)'), countryCode);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), countryName);

    await tester.tap(find.text('Choisir une devise'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(currencyName).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fuseau horaire (ex. Africa/Conakry)'),
      'Africa/Conakry',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Langues (séparées par des virgules)'), 'fr');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Moyens de paiement (séparés par des virgules)'),
      'cash',
    );

    await _submitDialog(tester, 'Créer');

    expect(find.textContaining(countryName), findsOneWidget);

    // --- Villes tab ---
    await tester.tap(find.text('Villes'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Ajouter une ville'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 2)); // dialog's own referenceCountriesProvider fetch
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choisir un pays'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text(countryName).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la ville'), cityName);
    await tester.enterText(find.widgetWithText(TextFormField, 'Région'), 'Test Region');

    await _submitDialog(tester, 'Créer');

    expect(find.text(cityName), findsOneWidget);
  });
}
