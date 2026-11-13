import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/domain/topic_starter_examples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects starter search queries by native language', () {
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.ko),
      <String>[
        '이번 주말 계획',
        '좋아하는 음식',
        '최근 본 영화',
        '가보고 싶은 곳',
        '오사카 맛집 여행',
        '요즘 즐기는 취미',
      ],
    );
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.en),
      <String>[
        'Weekend plans',
        'Favorite food',
        'Recent movie',
        'Dream destination',
        'Osaka food trip',
        'Favorite hobby',
      ],
    );
    expect(
      TopicStarterExamples.forNativeLanguage(LearningLanguageCode.zh),
      <String>['这个周末的计划', '喜欢的食物', '最近看过的电影', '想去的地方', '大阪美食之旅', '最近喜欢的爱好'],
    );
  });
}
