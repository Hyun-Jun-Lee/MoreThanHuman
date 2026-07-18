import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase dart-define values are required when app initializes', () {
    expect(AppConfig.supabaseUrl, '');
    expect(AppConfig.supabasePublishableKey, '');
    expect(() => AppConfig.requiredSupabaseUrl, throwsStateError);
    expect(() => AppConfig.requiredSupabasePublishableKey, throwsStateError);
  });
}
