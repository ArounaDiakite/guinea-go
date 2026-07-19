// Real end-to-end test against the live local backend - no HTTP
// mocking. Uses the seeded store_manager_e2e_fixture account (same
// bootstrap pattern as the other partner-role E2E fixtures) to create
// two brand-new stores/products for every run, so this test never
// collides with another run's cart state or the permanent demo seed.
//
// The two cart items are pre-seeded directly against the backend
// (rather than through the catalog UI) - the "search then add to
// cart" flow is already covered end-to-end by commerce_catalog_test.
// This test is specifically about the cart screen itself: per-store
// grouping, the nav badge, editing quantity, removing an item, and the
// total recalculating - so it starts from an already-populated cart.

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
import 'package:guinea_go/core/utils/currency.dart';
import 'package:guinea_go/features/commerce/presentation/cart_screen.dart';
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
          GoRoute(
            path: 'cart',
            builder: (context, state) => const CartScreen(),
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
  late String storeAId;
  late String storeAName;
  late String storeBId;
  late String storeBName;
  late String productAId;
  late String productAName;
  late double productAPrice;
  late String productBId;
  late String productBName;
  late double productBPrice;

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

    Future<(String, String)> createStore(String label) async {
      final name = '$label E2E $uniqueSuffix';
      final response = await setupDio.post<Map<String, dynamic>>(
        '/stores/',
        data: {
          'name': name,
          'phone': '+224621000001',
          'email': '${label.toLowerCase()}.e2e.$uniqueSuffix@test.com',
          'country_id': guinea['id'],
          'city_id': conakryCity['id'],
          'address': 'Quartier Kaloum, Conakry',
        },
        options: ownerAuthHeader,
      );
      return (response.data!['id'] as String, name);
    }

    Future<(String, String, double)> createProduct(String storeId, String label, double price) async {
      final name = '$label E2E $uniqueSuffix';
      final response = await setupDio.post<Map<String, dynamic>>(
        '/products/',
        data: {'store_id': storeId, 'name': name, 'price': price, 'stock': 10},
        options: ownerAuthHeader,
      );
      return (response.data!['id'] as String, name, price);
    }

    (storeAId, storeAName) = await createStore('BoutiqueA');
    (storeBId, storeBName) = await createStore('BoutiqueB');
    (productAId, productAName, productAPrice) = await createProduct(storeAId, 'ProduitA', 15000);
    (productBId, productBName, productBPrice) = await createProduct(storeBId, 'ProduitB', 25000);
  });

  tearDownAll(() async {
    for (final productId in [productAId, productBId]) {
      try {
        await setupDio.delete<void>('/products/$productId', options: ownerAuthHeader);
      } catch (_) {}
    }
    for (final storeId in [storeAId, storeBId]) {
      try {
        await setupDio.delete<void>('/stores/$storeId', options: ownerAuthHeader);
      } catch (_) {}
    }
    setupDio.close();
  });

  testWidgets('cart badge, per-store grouping, quantity edit, and removal', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_commerce_cart_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'CommerceCart',
        lastName: 'Tester',
        email: email,
        phone: '+224699000500',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    // Pre-seed the cart directly - product A x2 (store A), product B x1
    // (store B) - so the widget test starts from a populated, two-store
    // cart without re-driving the catalog UI (already covered by
    // commerce_catalog_test.dart).
    await tester.runAsync(() async {
      final passengerToken = await TokenStorage.readAccessToken();
      final passengerAuthHeader = Options(headers: {'Authorization': 'Bearer $passengerToken'});
      await setupDio.post<void>(
        '/cart/items',
        data: {'product_id': productAId, 'quantity': 2},
        options: passengerAuthHeader,
      );
      await setupDio.post<void>(
        '/cart/items',
        data: {'product_id': productBId, 'quantity': 1},
        options: passengerAuthHeader,
      );
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // GET /categories/ + GET /products/ (unfiltered, catalog) and,
      // concurrently, the AppBar's own GET /cart/ for the badge count.
      await Future.delayed(const Duration(seconds: 6));
    });
    await tester.pumpAndSettle();

    // 2 (product A) + 1 (product B) = 3 total items. The key is on the
    // Text widget itself (a leaf), so it's read directly rather than
    // via find.descendant (which looks for a nested match and would
    // always find none inside a leaf widget).
    expect(tester.widget<Text>(find.byKey(const ValueKey('cart-badge-count'))).data, '3');

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Panier'));
      await tester.pump();
      // Cart provider is already resolved/cached from the AppBar badge,
      // but give it a real margin in case Riverpod re-fetches anyway.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('Panier'), findsWidgets);
    expect(find.text(storeAName), findsOneWidget);
    expect(find.text(storeBName), findsOneWidget);
    expect(find.text(productAName), findsOneWidget);
    expect(find.text(productBName), findsOneWidget);

    final expectedInitialTotal = formatGnf(productAPrice * 2 + productBPrice * 1);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cart-grand-total'))).data, expectedInitialTotal);

    // Bump product B from 1 to 2.
    await tester.ensureVisible(find.byKey(ValueKey('cart-item-increment-$productBId')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('cart-item-increment-$productBId')));
      await tester.pump();
      // Real PUT /cart/items/{productId} + the resulting GET /cart/ refetch.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(ValueKey('cart-item-quantity-$productBId'))).data,
      '2',
    );
    final expectedBumpedTotal = formatGnf(productAPrice * 2 + productBPrice * 2);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cart-grand-total'))).data, expectedBumpedTotal);

    // Remove product A entirely - its whole store group should disappear.
    await tester.ensureVisible(find.byKey(ValueKey('cart-item-remove-$productAId')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('cart-item-remove-$productAId')));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text(storeAName), findsNothing);
    expect(find.text(productAName), findsNothing);
    expect(find.text(storeBName), findsOneWidget);
    final expectedFinalTotal = formatGnf(productBPrice * 2);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cart-grand-total'))).data, expectedFinalTotal);
  });
}
