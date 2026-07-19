// Real end-to-end test against the live local backend - no HTTP
// mocking. Uses the seeded store_manager_e2e_fixture account to create
// a brand-new store/product for every run. The cart item is pre-seeded
// directly against the backend (the "search then add to cart" flow is
// already covered by commerce_catalog_test.dart) - this test is
// specifically about checkout -> "Mes commandes" -> payment -> the
// order showing confirmed, and the cart being empty afterward.

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
import 'package:guinea_go/features/commerce/models/order_summary.dart';
import 'package:guinea_go/features/commerce/presentation/cart_screen.dart';
import 'package:guinea_go/features/commerce/presentation/checkout_screen.dart';
import 'package:guinea_go/features/commerce/presentation/my_orders_screen.dart';
import 'package:guinea_go/features/commerce/presentation/order_detail_screen.dart';
import 'package:guinea_go/features/identity/application/auth_controller.dart';
import 'package:guinea_go/features/payments/models/payment.dart';
import 'package:guinea_go/features/payments/presentation/payment_screen.dart';

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
    initialLocation: '/hub/commerce/cart',
    routes: [
      GoRoute(
        path: '/hub/commerce/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/hub/commerce/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/hub/commerce/orders',
        builder: (context, state) => const MyOrdersScreen(),
        routes: [
          GoRoute(
            path: ':orderId',
            builder: (context, state) => OrderDetailScreen(summary: state.extra as OrderSummary),
            routes: [
              GoRoute(
                path: 'payment',
                builder: (context, state) => PaymentScreen(request: state.extra as PaymentRequest),
              ),
            ],
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
    storeName = 'Boutique Checkout E2E $uniqueSuffix';

    final storeResponse = await setupDio.post<Map<String, dynamic>>(
      '/stores/',
      data: {
        'name': storeName,
        'phone': '+224621000002',
        'email': 'checkout.e2e.$uniqueSuffix@test.com',
        'country_id': guinea['id'],
        'city_id': conakryCity['id'],
        'address': 'Quartier Kaloum, Conakry',
      },
      options: ownerAuthHeader,
    );
    storeId = storeResponse.data!['id'] as String;

    productName = 'Produit Checkout E2E $uniqueSuffix';
    price = (10000 + (uniqueSuffix % 50000)).toDouble();

    final productResponse = await setupDio.post<Map<String, dynamic>>(
      '/products/',
      data: {'store_id': storeId, 'name': productName, 'price': price, 'stock': 5},
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

  testWidgets('cart -> checkout -> pay -> order confirmed, cart emptied', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
    final email = 'flutter_commerce_checkout_$uniqueSuffix@test.com';

    final authContainer = ProviderContainer();
    await tester.runAsync(() async {
      await authContainer.read(authControllerProvider.notifier).register(
        firstName: 'CommerceCheckout',
        lastName: 'Tester',
        email: email,
        phone: '+224699000600',
        password: 'TestPass123!',
        city: 'Conakry',
      );
    });
    authContainer.dispose();

    late String passengerToken;
    await tester.runAsync(() async {
      passengerToken = (await TokenStorage.readAccessToken())!;
      await setupDio.post<void>(
        '/cart/items',
        data: {'product_id': productId, 'quantity': 2},
        options: Options(headers: {'Authorization': 'Bearer $passengerToken'}),
      );
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestApp());
      // GET /cart/.
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    final expectedTotal = formatGnf(price * 2);
    expect(tester.widget<Text>(find.byKey(const ValueKey('cart-grand-total'))).data, expectedTotal);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Passer la commande'));
      await tester.pump();
      // Checkout screen watches the same cartProvider, already resolved.
      await Future.delayed(const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(find.text('Récapitulatif de commande'), findsOneWidget);
    expect(find.text(storeName), findsOneWidget);
    expect(find.text('1 commande sera créée, une par boutique.'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer la commande'));
      await tester.pump();
      // Real POST /orders/checkout round trip, then context.go navigates
      // to /hub/commerce/orders, which fires its own GET /orders/me +
      // per-order GET /stores/{id}.
      await Future.delayed(const Duration(seconds: 4));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('Mes commandes'), findsWidgets);
    expect(find.text(storeName), findsOneWidget);
    expect(find.text('En attente de paiement'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer'));
      await tester.pump();
      // GET /orders/{id} for the detail screen.
      await Future.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();

    expect(find.text('Détail de la commande'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('Paiement'), findsOneWidget);
    expect(find.text('Réservation en attente de paiement'), findsOneWidget);
    expect(find.text(expectedTotal), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Payer maintenant'));
      await tester.pump();
      // POST /orders/{id}/payments (immediate "pending" response), then
      // the screen's own internal wait for the sandbox background task
      // to confirm, then its own GET /orders/{id} status re-check.
      await Future.delayed(const Duration(seconds: 8));
    });
    await tester.pumpAndSettle();

    expect(find.text('Réservation confirmée !'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Voir mes réservations'));
      await tester.pump();
      await Future.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();

    expect(find.text('Mes commandes'), findsWidgets);
    expect(find.text('Confirmée'), findsOneWidget);

    // Cart was emptied by checkout - confirm directly against the backend.
    await tester.runAsync(() async {
      final cartResponse = await setupDio.get<Map<String, dynamic>>(
        '/cart/',
        options: Options(headers: {'Authorization': 'Bearer $passengerToken'}),
      );
      final items = (cartResponse.data!['items'] as List<dynamic>);
      expect(items, isEmpty);
    });
  });
}
