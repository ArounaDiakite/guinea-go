import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

/// Global session state: null means "not logged in", a User means
/// logged in as them. State updates on success so anything watching it
/// (the home placeholder today, a router redirect guard later) sees
/// the same source of truth - but methods also rethrow on failure so
/// the calling screen can show the error inline in its own form
/// instead of only reacting to global state.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async => null;

  Future<void> login({required String email, required String password}) async {
    try {
      final session = await ref.read(authRepositoryProvider).login(
        email: email,
        password: password,
      );
      await TokenStorage.saveAccessToken(session.accessToken);
      state = AsyncData(session.user);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String city,
  }) async {
    try {
      final session = await ref.read(authRepositoryProvider).register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
        city: city,
      );
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
