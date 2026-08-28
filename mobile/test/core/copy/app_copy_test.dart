import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCopy', () {
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

    test('builds system-locale pair framing without changing language codes', () {
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
    });
  });
}
