import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/domain/topic_starter_examples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects starter search queries by native language', () {
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.ko),
      contains('이번 주 AI 뉴스'),
    );
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.en),
      contains('AI news this week'),
    );
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.zh),
      contains('本周 AI 新闻'),
    );
  });
}
