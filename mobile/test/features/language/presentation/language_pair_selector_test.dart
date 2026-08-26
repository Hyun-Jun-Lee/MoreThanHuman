import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables language pairs that include Chinese', (
    WidgetTester tester,
  ) async {
    LearningLanguageContext? changed;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: LanguagePairSelector(
            selected: LearningLanguageContext.defaultContext,
            localeCode: 'en',
            onChanged: (LearningLanguageContext next) => changed = next,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chinese -> English'));
    expect(changed, isNull);

    await tester.tap(find.text('English -> Korean'));
    expect(
      changed,
      const LearningLanguageContext(
        nativeLanguage: LearningLanguageCode.en,
        targetLanguage: LearningLanguageCode.ko,
        feedbackLanguage: LearningLanguageCode.en,
      ),
    );
  });
}
