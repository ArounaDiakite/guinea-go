import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Central place for environment-level constants. Only one value today
/// (the API base URL) - grows into real per-environment config
/// (dev/staging/prod base URLs via --dart-define) once there's more
/// than one backend to point at.
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator runs in its own network namespace, so
  /// 127.0.0.1/localhost from inside it refers to the emulator itself,
  /// not the host machine running the backend - 10.0.2.2 is the
  /// emulator's alias for the host loopback. Web/desktop/iOS-simulator
  /// all share the host's loopback directly, so 127.0.0.1 is correct
  /// there. --dart-define=API_BASE_URL always wins over both.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
