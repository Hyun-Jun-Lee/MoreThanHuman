abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8010/api/',
  );

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static String? get optionalGoogleClientId => _optional(googleClientId);

  static String? get optionalGoogleServerClientId =>
      _optional(googleServerClientId);

  static String? _optional(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
