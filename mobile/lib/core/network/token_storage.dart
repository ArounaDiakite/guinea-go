import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over flutter_secure_storage so the rest of the app
/// never talks to the storage package directly - if the storage
/// mechanism ever changes, this is the only file that needs to know.
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'guinea_go_access_token';

  static Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<void> clear() {
    return _storage.delete(key: _accessTokenKey);
  }
}
