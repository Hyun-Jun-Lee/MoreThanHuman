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

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static String? get optionalGoogleClientId => _optional(googleClientId);

  static String? get optionalGoogleServerClientId =>
      _optional(googleServerClientId);

  static String get requiredSupabaseUrl =>
      _required(supabaseUrl, 'SUPABASE_URL');

  static String get requiredSupabasePublishableKey =>
      _required(supabasePublishableKey, 'SUPABASE_PUBLISHABLE_KEY');

  static String? _optional(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String _required(String value, String name) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw StateError('$name must be provided with --dart-define.');
    }
    return normalized;
  }
}
