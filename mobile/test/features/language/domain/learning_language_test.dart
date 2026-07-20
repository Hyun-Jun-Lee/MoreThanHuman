import 'package:curitalk/features/language/language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to Korean native and English target for legacy profiles', () {
    final LearningLanguageContext context = LearningLanguageContext.fromJson(
      null,
    );

    expect(context.nativeLanguage, LearningLanguageCode.ko);
    expect(context.targetLanguage, LearningLanguageCode.en);
    expect(context.feedbackLanguage, LearningLanguageCode.ko);
  });

  test('parses and serializes the backend language preference payload', () {
    final LearningLanguageContext context = LearningLanguageContext.fromJson(
      <String, dynamic>{
        'native_language': 'zh',
        'target_language': 'ko',
        'feedback_language': 'zh',
      },
    );

    expect(context.toJson(), <String, dynamic>{
      'native_language': 'zh',
      'target_language': 'ko',
      'feedback_language': 'zh',
    });
    expect(context.toStorageValue(), 'zh|ko|zh');
  });

  test('infers a first-run default from the app locale', () {
    expect(
      defaultLanguageContextForLocale('en').targetLanguage,
      LearningLanguageCode.ko,
    );
    expect(
      defaultLanguageContextForLocale('zh').nativeLanguage,
      LearningLanguageCode.zh,
    );
    expect(
      defaultLanguageContextForLocale('ko').targetLanguage,
      LearningLanguageCode.en,
    );
  });
}
