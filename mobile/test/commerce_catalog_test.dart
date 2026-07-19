// Real end-to-end test against the live local backend - no HTTP
// mocking. Uses the seeded store_manager_e2e_fixture account (same
// bootstrap pattern as hotel_owner_e2e_fixture/event_organizer_e2e_
// fixture: registered once via /auth/register, then role-flipped
// directly in Mongo) to create a brand-new store + product for every
// run, so this test never collides with another run's catalog state or
// with the permanent demo seed data (backend/app/database/seed.py).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:guinea_go/core/config/app_config.dart';
import 'package:guinea_go/core/network/token_storage.dart';
import 'package:guinea_go/core/theme/app_theme.dart';
import 'package:guinea_go/features/commerce/presentation/product_catalog_screen.dart';
import 'package:guinea_go/features/commerce/presentation/product_detail_screen.dart';
import 'package:guinea_go/features/commerce/presentation/store_screen.dart';
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

Widget buildTestApp() {
  final router = GoRouter(
    initialLocation: '/hub/commerce',
    routes: [
      GoRoute(
        path: '/hub/commerce',
        builder: (context, state) => const ProductCatalogScreen(),
        routes: [
          GoRoute(
            path: 'products/:productId',
            builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['productId']!),
          ),
          GoRoute(
            path: 'stores/:storeId',
            builder: (context, state) => StoreScreen(storeId: state.pathParameters['storeId']!),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUpMockSecureStorage();

  final setupDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  late Options ownerAuthHeader;
  late String storeId;
  late String storeName;
  late String productId;
  late String productName;
  late double price;

  setUpAll(() async {
    final loginResponse = await setupDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': _ownerEmail, 'password': _ownerPassword},
    );
    final ownerToken = loginResponse.data!['access_token'] as String;
    ownerAuthHeader = Options(headers: {'Authorization': 'Bearer $ownerToken'});

    final countriesResponse = await setupDio.get<List<dynamic>>('/countries/');
    final guinea = countriesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['code'] == 'GN');

    final citiesResponse = await setupDio.get<List<dynamic>>('/cities/', queryParameters: {'limit': 100});
    final conakryCity = citiesResponse.data!.cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Conakry');

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    storeName = 'Boutique E2E $uniqueSuffix';

    final storeResponse = await setupDio.post<Map<String, dynamic>>(
      '/stores/',
      data: {
        'name': storeName,
        'phone': '+224621000000',
        'email': 'boutique.e2e.$uniqueSuffix@test.com',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'address': 'Quartier Kaloum, Conakry',
      },
      options: ownerAuthHeader,
    );
    storeId = storeResponse.data!['id'] as String;

    productName = 'Produit E2E $uniqueSuffix';
    price = (10000 + (uniqueSuffix % 50000)).toDouble();

    final productResponse = await setupDio.post<Map<String, dynamic>>(
      '/products/',
      data: {
        'store_id': storeId,
        'name': productName,
        'description': 'Produit créé pour le test E2E du catalogue Commerce.',
        'price': price,
        'stock': 7,
      },
      options: ownerAuthHeader,
    );
    productId = productResponse.data!['id'] as String;
  });

  tearDownAll(() async {
    try {
      await setupDio.delete<void>('/products/$productId', options: ownerAuthHeader);
    } catch (_) {}
    try {
      await setupDio.delete<void>('/stores/$storeId', options: ownerAuthHeader);
    } catch (_) {}
    setupDio.close();
  });

  testWidgets('search the catalog, open a product, follow the store link, and add to cart', (tester) async {
    // Same real-phone-width technique as the other E2E tests, doubling
    // as overflow-regression coverage for these screens too.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_commerce_catalog_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'CommerceCatalog',
        lastName: 'Tester',
        email: email,
        phone: '+224699000400',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // GET /categories/ + GET /products/ (unfiltered) + a GET /stores/
      // per distinct product store.
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    // Search by the fixture's unique product name - scopes the result
    // list down to just this run's product regardless of how much other
    // catalog data (permanent demo seed, other concurrent runs) exists.
    // Both the debounce Timer firing AND the real GET /products/ + GET
    // /stores/ round trip it kicks off must share one runAsync block -
    // enterText alone (outside runAsync) schedules the Timer on the
    // fake-async test clock, and a real network call kicked off from a
    // callback running on that clock can never actually complete.
    await tester.runAsync(() async {
      await tester.enterText(find.byType(TextField), productName);
      // Lets the debounce Timer fire (real timer, real zone) - its
      // setState only marks the tree dirty, so a pump is still needed,
      // right here inside runAsync, to actually rebuild and kick off
      // the resulting GET /products/?search=... in this same real zone
      // (a pump outside runAsync can't drive a real Dio call to
      // completion - see the other real-network taps in this suite).
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    // productName also matches the search box's own echoed input, so
    // this only asserts "at least one" (the result card) rather than
    // pinning down an exact count; storeName isn't typed anywhere, so
    // it's unambiguous.
    expect(find.text(productName), findsAtLeastNWidgets(1));
    expect(find.text(storeName), findsOneWidget);

    // Tapped by icon rather than by productName text, since that text
    // also matches the search box above the results list. The tap
    // itself (not just the wait) has to run inside runAsync - it's
    // what kicks off GET /products/{id}, and a real Dio call started
    // outside runAsync never completes (see the search step above).
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
      await tester.pump();
      // GET /products/{id}.
      await Future.delayed(const Duration(seconds: 4));
      // _StoreLink only mounts - and only then starts its own GET
      // /stores/{id} - once productDetailProvider resolves and the
      // tree rebuilds past the loading state. Pump here, still inside
      // runAsync, so that fetch is created in the real zone too.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('7 en stock'), findsOneWidget);

    // Follow the store link to its own page - tapped by icon rather
    // than by storeName text, since the catalog screen underneath
    // (still mounted in the Navigator stack) shows that same text too.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      // GET /stores/{id}.
      await Future.delayed(const Duration(seconds: 4));
      // Same nested-provider staging as above: the products section
      // only mounts (and fetches) once the store itself has loaded.
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    // Store-screen-only info (not shown on the catalog/detail screens
    // underneath), confirming the store link actually navigated here.
    expect(find.text('Quartier Kaloum, Conakry'), findsOneWidget);
    expect(find.text('+224621000000'), findsOneWidget);

    // Back to the product detail screen to actually add it to the cart.
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Ajouter au panier'));
      await tester.pump();
      // Real POST /cart/items round trip.
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('Ajouté au panier.'), findsOneWidget);

    // No cart screen exists yet at this step - confirm the write landed
    // by reading the cart straight back from the backend instead.
    await tester.runAsync(() async {
      final passengerToken = await TokenStorage.readAccessToken();
      final cartResponse = await setupDio.get<Map<String, dynamic>>(
        '/cart/',
        options: Options(headers: {'Authorization': 'Bearer $passengerToken'}),
      );
      final items = (cartResponse.data!['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      final item = items.firstWhere((i) => i['product_id'] == productId);
      expect(item['quantity'], 3);
    });
  });
}
