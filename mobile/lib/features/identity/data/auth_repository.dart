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

  /// GET /users/me returns the same field set as the user embedded in
  /// TokenResponse (plus is_verified, which User.fromJson ignores) -
  /// used to restore the session on app start from a stored token,
  /// without the caller having to re-authenticate.
  Future<User> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(response.data!);
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

  /// Self-registration for a school_administrator-created Teacher/
  /// Student profile (POST /auth/register-school-member) - the
  /// invite_code identifies which profile (and its role) to claim;
  /// same TokenResponse-shaped body as register(), plus an ignored
  /// profile_id AuthSession.fromJson doesn't need.
  Future<AuthSession> registerSchoolMember({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String city,
    required String inviteCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register-school-member',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'city': city,
        'country_code': 'GN',
        'preferred_language': 'fr',
        'invite_code': inviteCode,
      },
    );
    return AuthSession.fromJson(response.data!);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
