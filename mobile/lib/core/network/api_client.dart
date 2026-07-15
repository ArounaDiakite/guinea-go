import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'token_storage.dart';

/// Attaches the stored JWT to every outgoing request automatically, and
/// clears it if the backend ever comes back with a 401 (expired/invalid
/// token) - callers never have to think about the header themselves.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.readAccessToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await TokenStorage.clear();
    }

    handler.next(err);
  }
}

Dio buildApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(_AuthInterceptor());

  return dio;
}

final apiClientProvider = Provider<Dio>((ref) => buildApiClient());
