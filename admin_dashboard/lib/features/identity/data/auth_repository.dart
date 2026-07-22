import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/user.dart';

/// Talks to /auth/login and /users/me. There is no register() here -
/// unlike mobile/, this app has no self-registration flow at all
/// (system_administrator accounts are created directly, not through any
/// public endpoint - see AuthService.register_role, used from a
/// one-off script, never from a router).
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

  Future<User> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(response.data!);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
