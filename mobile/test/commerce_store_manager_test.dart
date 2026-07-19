// Real end-to-end test against the live local backend - no HTTP
// mocking. Logs in as the pre-provisioned store_manager_e2e_fixture
// account (role flipped directly in MongoDB once, same bootstrapping
// gap as transport_driver_test.dart/transport_company_management_test.
// dart - register-partner requires admin activation and there's no
// seeded store_manager). This account is shared with commerce_catalog_
// test.dart/commerce_cart_test.dart/commerce_checkout_payment_test.dart,
// each of which creates and deletes its own temporary stores, so
// "Mes boutiques" may already contain other stores when this test
// starts (possibly created concurrently) - assertions are scoped to
// this run's own uniquely-named store/category/product rather than an
// exact count.
//
// Drives every real screen in the "Ma boutique" section: creates a
// store, a category, and a product tied to it, confirms the product is
// visible from the real passenger catalog (GET /products/?search=),
// then has a separate fresh passenger buy and pay for it (direct API -
// that whole flow is already covered end-to-end by commerce_catalog_
// test.dart/commerce_checkout_payment_test.dart) and confirms the
// resulting order shows up, correctly, in "Commandes reçues".

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
import 'package:guinea_go/features/identity/application/auth_controller.dart';

const _ownerEmail = 'store_manager_e2e_fixture@test.com';
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
    await tester.pump();
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownItem(WidgetTester tester, Finder dropdownFinder, String itemText) async {
  await tester.ensureVisible(dropdownFinder);
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
  final storeName = 'Boutique Manager E2E $uniqueSuffix';
  final categoryName = 'Catégorie E2E $uniqueSuffix';
  final productName = 'Produit Manager E2E $uniqueSuffix';

  late String storeId;
  late String categoryId;
  late String productId;
  late Options ownerAuthHeader;

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/products/$productId', options: ownerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/categories/$categoryId', options: ownerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/stores/$storeId', options: ownerAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets(
    'store_manager creates a store, category and product; the product is buyable and the order shows up as received',
    (tester) async {
      // Same real-phone-width technique as the other E2E tests, doubling
      // as overflow-regression coverage for these screens too. Below
      // _railBreakpoint (720) so the bottom NavigationBar is used, not
      // the wider NavigationRail.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authContainer = ProviderContainer();
      await tester.runAsync(() async {
        await authContainer.read(authControllerProvider.notifier).login(
          email: _ownerEmail,
          password: _ownerPassword,
        );
      });
      authContainer.dispose();

      await tester.runAsync(() async {
        await tester.pumpWidget(const ProviderScope(child: GuineaGoApp()));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3)); // connectivity + session restore + splash hold
        await tester.pump(); // go_router redirects straight to /hub/store (landingRouteForRole)
        await Future.delayed(const Duration(seconds: 2)); // myStoresProvider resolves
      });
      await tester.pumpAndSettle();

      // Session restore now lands store_manager directly on its own
      // branch (landingRouteForRole in hub_destinations.dart) rather
      // than on /hub/home - which used to leave the nav bar's "Ma
      // boutique" destination highlighted despite Home actually being
      // on screen, since /hub/home isn't one of this role's own
      // destinations for HubScaffold's selectedIndex to match.
      expect(find.text('Mes boutiques'), findsWidgets);
      final storeNavIcon = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.storefront_rounded),
      );
      expect(storeNavIcon, findsOneWidget);

      // --- Store ---
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la boutique'), storeName);
      await tester.enterText(find.widgetWithText(TextFormField, 'Téléphone'), '+224621000$uniqueSuffix'.substring(0, 16));
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'boutique_e2e_$uniqueSuffix@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Adresse'), 'Kaloum, Conakry');

      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<Country>), 'Guinea');
      await _selectDropdownItem(tester, find.byType(DropdownButtonFormField<City>), 'Conakry');

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer la boutique'));

      expect(find.text(storeName), findsOneWidget);

      // --- Store manage menu ---
      await _tapAndSettle(tester, find.text(storeName));

      expect(find.text('Gérer la boutique'), findsOneWidget);
      expect(find.text('Produits'), findsOneWidget);

      // --- Category (global, shared across every store) ---
      await _tapAndSettle(tester, find.text('Catégories'));
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom de la catégorie'), categoryName);
      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Créer la catégorie'));

      expect(find.text(categoryName), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Gérer la boutique'), findsOneWidget);

      // --- Product ---
      await _tapAndSettle(tester, find.text('Produits'));
      await _tapAndSettle(tester, find.byType(FloatingActionButton));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom du produit'), productName);
      await tester.enterText(find.widgetWithText(TextFormField, 'Prix (GNF)'), '35000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Stock'), '12');

      // Pick the category chip just created, among any others visible.
      await tester.ensureVisible(find.widgetWithText(FilterChip, categoryName));
      await tester.tap(find.widgetWithText(FilterChip, categoryName));
      await tester.pumpAndSettle();

      await _submitAndSettle(tester, find.widgetWithText(ElevatedButton, 'Ajouter le produit'));

      expect(find.text(productName), findsOneWidget);
      expect(find.text('12 en stock'), findsOneWidget);

      // --- The product is real: fetch its and its store's ids, and
      // confirm a fresh passenger can see it in the public catalog. ---
      late Options passengerAuthHeader;
      await tester.runAsync(() async {
        final loginResponse = await setupDio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': _ownerEmail, 'password': _ownerPassword},
        );
        final token = loginResponse.data!['access_token'] as String;
        ownerAuthHeader = Options(headers: {'Authorization': 'Bearer $token'});

        final products = await setupDio.get<List<dynamic>>(
          '/products/',
          queryParameters: {'search': productName, 'limit': 5},
        );
        final product = products.data!.cast<Map<String, dynamic>>().single;
        productId = product['id'] as String;
        storeId = product['store_id'] as String;

        final categories = await setupDio.get<List<dynamic>>(
          '/categories/',
          queryParameters: {'search': categoryName, 'limit': 5},
        );
        categoryId = categories.data!.cast<Map<String, dynamic>>().single['id'] as String;

        // A separate, fresh passenger buys and pays for it - the
        // catalog/cart/checkout UI flows themselves are already fully
        // covered elsewhere, so this is a direct API round trip purely
        // to produce a real CONFIRMED order for "Commandes reçues" to
        // display.
        final passengerEmail = 'commerce_store_manager_buyer_$uniqueSuffix@test.com';
        final registerResponse = await setupDio.post<Map<String, dynamic>>('/auth/register', data: {
          'first_name': 'StoreManagerBuyer',
          'last_name': 'Tester',
          'email': passengerEmail,
          'phone': '+224699000700',
          'password': 'TestPass123!',
          'city': 'Conakry',
        });
        final passengerToken = registerResponse.data!['access_token'] as String;
        passengerAuthHeader = Options(headers: {'Authorization': 'Bearer $passengerToken'});

        await setupDio.post<void>(
          '/cart/items',
          data: {'product_id': productId, 'quantity': 2},
          options: passengerAuthHeader,
        );
        final checkoutResponse = await setupDio.post<List<dynamic>>('/orders/checkout', options: passengerAuthHeader);
        final order = checkoutResponse.data!.cast<Map<String, dynamic>>().single;
        final orderId = order['id'] as String;

        await setupDio.post<void>(
          '/orders/$orderId/payments',
          data: {'provider': 'orange_money', 'amount': order['total']},
          options: passengerAuthHeader,
        );
        // Sandbox confirmation runs on a ~2s background task.
        await Future.delayed(const Duration(seconds: 4));
      });

      // --- Back in the store_manager's own session: "Commandes reçues" ---
      await tester.pageBack(); // product list -> store manage menu
      await tester.pumpAndSettle();
      expect(find.text('Gérer la boutique'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Commandes reçues'), wait: const Duration(seconds: 3));

      expect(find.text('Commandes reçues'), findsWidgets);
      expect(find.text('2 articles'), findsOneWidget);
      expect(find.text('Confirmée'), findsOneWidget);
      expect(find.textContaining(productName), findsOneWidget);
    },
  );
}
