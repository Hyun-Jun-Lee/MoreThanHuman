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

  test('formats a compact language pair label from language codes', () {
    expect(LearningLanguageContext.defaultContext.shortPairLabel(), 'KR -> EN');
    expect(
      const LearningLanguageContext(
        nativeLanguage: LearningLanguageCode.zh,
        targetLanguage: LearningLanguageCode.ko,
        feedbackLanguage: LearningLanguageCode.zh,
      ).shortPairLabel(),
      'ZH -> KR',
    );
  });

  test('infers a first-run default from the app locale', () {
    expect(
      defaultLanguageContextForLocale('en').targetLanguage,
      LearningLanguageCode.ko,
    );
    expect(
      defaultLanguageContextForLocale('zh').nativeLanguage,
      LearningLanguageCode.ko,
    );
    expect(
      defaultLanguageContextForLocale('ko').targetLanguage,
      LearningLanguageCode.en,
    );
  });

  test(
    'marks language pairs with Chinese as unavailable in mobile selector',
    () {
      expect(
        LearningLanguageContext.defaultContext.isAvailableInMobileSelector,
        isTrue,
      );
      expect(
        const LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.zh,
          targetLanguage: LearningLanguageCode.en,
          feedbackLanguage: LearningLanguageCode.zh,
        ).isAvailableInMobileSelector,
        isFalse,
      );
    },
  );

  test('describes preference changes as new-conversations-only by locale', () {
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('en'),
      contains('new conversations'),
    );
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('en'),
      contains('Existing conversations'),
    );
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('ko'),
      contains('새 대화'),
    );
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('ko'),
      contains('기존 대화'),
    );
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('zh'),
      contains('新对话'),
    );
    expect(
      LearningLanguageContext.defaultContext.preferenceChangePolicyText('zh'),
      contains('现有对话'),
    );
  });
}
