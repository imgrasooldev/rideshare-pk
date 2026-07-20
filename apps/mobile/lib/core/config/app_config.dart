/// Compile-time configuration. Override per environment:
///   flutter run --dart-define=API_BASE_URL=http://localhost:4000
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rideshare-pk.fly.dev',
  );

  static const apiPrefix = '/api/v1';
}
