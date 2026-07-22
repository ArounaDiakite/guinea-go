import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

/// This dashboard is reserved to system_administrator - every other
/// role authenticates fine against the backend (the same /auth/login
/// any Guinea Go account uses) but has no business being in here.
/// Thrown instead of persisting a session for them, so the login
/// screen can show a specific, honest reason rather than a generic
/// error.
class NotSystemAdministratorException implements Exception {
  const NotSystemAdministratorException();
}

/// Global session state: null means "not logged in", a User means
/// logged in as them (always a system_administrator - see login()).
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = await TokenStorage.readAccessToken();
    if (token == null) return null;

    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      if (user.role != 'system_administrator') {
        await TokenStorage.clear();
        return null;
      }
      return user;
    } catch (_) {
      await TokenStorage.clear();
      return null;
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final session = await ref.read(authRepositoryProvider).login(
        email: email,
        password: password,
      );

      if (session.user.role != 'system_administrator') {
        throw const NotSystemAdministratorException();
      }

      await TokenStorage.saveAccessToken(session.accessToken);
      state = AsyncData(session.user);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
