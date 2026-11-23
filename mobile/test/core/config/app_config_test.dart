import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase dart-define values are required when app initializes', () {
    expect(AppConfig.supabaseUrl, '');
    expect(AppConfig.supabasePublishableKey, '');
    expect(() => AppConfig.requiredSupabaseUrl, throwsStateError);
    expect(() => AppConfig.requiredSupabasePublishableKey, throwsStateError);
  });

  test('privacy policy defaults follow the app language', () {
    expect(
      AppConfig.privacyPolicyUrlFor(isKorean: true),
      'https://www.curitalk.app/privacy',
    );
    expect(
      AppConfig.privacyPolicyUrlFor(isKorean: false),
      'https://www.curitalk.app/en/privacy',
    );
  });
}
