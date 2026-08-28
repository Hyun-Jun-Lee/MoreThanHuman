import 'package:curitalk/features/language/domain/learning_language.dart';

abstract final class TopicStarterExamples {
  static List<String> forNativeLanguage(LearningLanguageCode language) {
    return switch (language) {
      LearningLanguageCode.ko => const <String>[
        '이번 주 AI 뉴스',
        '오사카 맛집 여행',
        '월드컵 예선 경기',
        'Apple WWDC 업데이트',
      ],
      LearningLanguageCode.en => const <String>[
        'AI news this week',
        'Osaka food trip',
        'World Cup qualifier',
        'Apple WWDC update',
      ],
      LearningLanguageCode.zh => const <String>[
        '本周 AI 新闻',
        '大阪美食之旅',
        '世界杯预选赛',
        'Apple WWDC 更新',
      ],
    };
  }
}
