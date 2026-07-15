import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

/// Test call used to validate the app can actually reach the backend -
/// hits the API's own root endpoint (lightweight, unauthenticated,
/// always available) rather than a real domain endpoint.
final backendConnectivityProvider = FutureProvider.autoDispose<String>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/');
  return response.data['message'] as String? ?? 'Connecté';
});
