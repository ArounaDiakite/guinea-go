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

/// A connectionError/connectionTimeout means the request never reached
/// the server at all (nothing was submitted), so retrying is safe
/// regardless of HTTP method - unlike a receiveTimeout, where the
/// server may already be processing the original request. Backs off a
/// few seconds before each attempt: a transient connect failure right
/// after another one tends to fail again immediately, but recovers
/// once real time has actually passed.
class _RetryOnConnectionErrorInterceptor extends Interceptor {
  static const _maxAttempts = 2;
  static const _backoff = Duration(seconds: 3);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isConnectionFailure =
        err.type == DioExceptionType.connectionError || err.type == DioExceptionType.connectionTimeout;
    final attempt = (err.requestOptions.extra['retryAttempt'] as int?) ?? 0;

    if (!isConnectionFailure || attempt >= _maxAttempts) {
      handler.next(err);
      return;
    }

    try {
      await Future.delayed(_backoff);
      err.requestOptions.extra['retryAttempt'] = attempt + 1;
      final response = await Dio().fetch(err.requestOptions);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
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

  // Interceptors' onError runs in reverse registration order, so this
  // retry attempt happens before _AuthInterceptor's 401-handling sees
  // the (now possibly resolved) result.
  dio.interceptors.add(_AuthInterceptor());
  dio.interceptors.add(_RetryOnConnectionErrorInterceptor());

  return dio;
}

final apiClientProvider = Provider<Dio>((ref) {
  final dio = buildApiClient();
  ref.onDispose(dio.close);
  return dio;
});
