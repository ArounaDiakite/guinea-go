import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/user.dart';

/// Talks to /auth/register and /auth/login. Both endpoints return the
/// same TokenResponse shape (access_token + user), which is why
/// AuthSession.fromJson works for either response unmodified -
/// registering a passenger logs them in immediately, same as the
/// backend does.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthSession> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response.data!);
  }

  /// Public passenger self-registration (POST /auth/register) -
  /// always creates a `passenger` account, active immediately. Partner
  /// roles (company_owner, hotel_owner, ...) go through a different
  /// endpoint the app doesn't expose yet.
  Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String city,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'city': city,
        'country_code': 'GN',
        'preferred_language': 'fr',
      },
    );
    return AuthSession.fromJson(response.data!);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
