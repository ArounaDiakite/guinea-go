/// Central place for environment-level constants. Only one value today
/// (the API base URL) - grows into real per-environment config
/// (dev/staging/prod base URLs via --dart-define) once there's more
/// than one backend to point at.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
