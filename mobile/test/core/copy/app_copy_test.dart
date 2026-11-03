import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCopy', () {
    test('shows plan slot benefits in the paywall locale', () {
      final korean = AppCopy.forLocale(const Locale('ko'));
      final english = AppCopy.forLocale(const Locale('en'));

      expect(korean.planBenefits(false), '전체 대화 슬롯의 절반 해금');
      expect(korean.planBenefits(true), '전체 대화 슬롯 해금');
      expect(
        english.planBenefits(false),
        'Unlock half of all conversation slots',
      );
      expect(english.planBenefits(true), 'Unlock all conversation slots');
      expect(korean.plusBusinessConversationBenefit, '비즈니스 대화 모드');
      expect(
        english.plusBusinessConversationBenefit,
        'Business Conversation Mode',
      );
    });

    test('labels the profile language section', () {
      expect(
        AppCopy.forLocale(const Locale('ko')).languagePairSectionLabel,
        '학습 언어',
      );
      expect(
        AppCopy.forLocale(const Locale('en')).languagePairSectionLabel,
        'Learning Language',
      );
    });
    test('localizes the debug basket reset tooltip', () {
      expect(
        AppCopy.forLocale(const Locale('ko')).resetSnackBasketTooltip,
        '바구니 리셋 (테스트용)',
      );
      expect(
        AppCopy.forLocale(const Locale('en')).resetSnackBasketTooltip,
        'Reset basket (test)',
      );
    });
    test('uses Korean only for Korean system locales', () {
      expect(AppCopy.resolveLocaleCode(const Locale('ko')), 'ko');
      expect(AppCopy.resolveLocaleCode(const Locale('ko', 'KR')), 'ko');
      expect(AppCopy.resolveLocaleCode(const Locale('en')), 'en');
      expect(AppCopy.resolveLocaleCode(const Locale('en', 'US')), 'en');
      expect(AppCopy.resolveLocaleCode(const Locale('ja')), 'en');
    });

    test('formats known learning language codes in the UI locale', () {
      final AppCopy korean = AppCopy.forLocale(const Locale('ko'));
      final AppCopy english = AppCopy.forLocale(const Locale('en'));

      expect(korean.languageName('en'), '영어');
      expect(korean.languageName('ko'), '한국어');
      expect(korean.languageName('zh'), '중국어');
      expect(english.languageName('en'), 'English');
      expect(english.languageName('ko'), 'Korean');
      expect(english.languageName('zh'), 'Chinese');
      expect(korean.languageName('fr'), 'fr');
    });

    test('uses the same conversation badge labels in Korean and English', () {
      for (final locale in [const Locale('ko'), const Locale('en')]) {
        final copy = AppCopy.forLocale(locale);
        expect(copy.conversationCategory('freeChat'), 'freechat');
        expect(copy.conversationCategory('roleplay'), 'roleplaying');
      }
    });

    test(
      'builds system-locale pair framing without changing language codes',
      () {
        expect(
          AppCopy.forLocale(const Locale('ko')).languagePairDescription(
            nativeCode: 'en',
            targetCode: 'ko',
            feedbackCode: 'en',
          ),
          '대화: 한국어 · 피드백: 영어',
        );
        expect(
          AppCopy.forLocale(const Locale('en')).firstAnswerHint('ko'),
          'Type your first answer in Korean...',
        );
      },
    );
  });
}
