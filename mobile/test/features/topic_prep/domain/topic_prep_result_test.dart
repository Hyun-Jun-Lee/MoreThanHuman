import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a ready topic prep result', () {
    final TopicPrepResult result = TopicPrepResult.fromJson(_readyResult());

    expect(result.ready, isTrue);
    expect(result.card?.summary, 'Lotte won 8-3 after ending a losing streak.');
    expect(result.card?.sources.first.title, 'Lotte game recap');
    expect(result.card?.directions, hasLength(4));
    expect(
      result.card?.directions.first.direction,
      TopicPrepDirectionType.casualChat,
    );
    expect(result.card?.directions.first.firstQuestions, hasLength(3));
    expect(result.language.nativeLanguage, LearningLanguageCode.zh);
    expect(result.language.targetLanguage, LearningLanguageCode.ko);
  });

  test('parses a low-quality topic prep result', () {
    final TopicPrepResult result = TopicPrepResult.fromJson(<String, dynamic>{
      'ready': false,
      'card': null,
      'quality': _quality(isSufficient: false),
      'retry_guidance': 'Try a more specific topic.',
      'example_topics': <String>['recent Lotte Giants game'],
    });

    expect(result.ready, isFalse);
    expect(result.card, isNull);
    expect(result.retryGuidance, 'Try a more specific topic.');
    expect(result.exampleTopics, <String>['recent Lotte Giants game']);
  });

  test('rejects unknown direction values', () {
    final Map<String, dynamic> json = _readyResult();
    final List<dynamic> directions =
        (json['card']! as Map<String, dynamic>)['directions']! as List<dynamic>;
    directions[0] = <String, dynamic>{
      ...(directions[0]! as Map<String, dynamic>),
      'direction': 'UNKNOWN',
    };

    expect(() => TopicPrepResult.fromJson(json), throwsFormatException);
  });

  test('rejects ready results without a card', () {
    expect(
      () => TopicPrepResult.fromJson(<String, dynamic>{
        'ready': true,
        'card': null,
        'quality': _quality(),
        'retry_guidance': null,
        'example_topics': <String>[],
      }),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _readyResult() {
  return <String, dynamic>{
    'ready': true,
    'language': <String, String>{
      'native_language': 'zh',
      'target_language': 'ko',
      'feedback_language': 'zh',
    },
    'card': <String, dynamic>{
      'topic': '최근 롯데 자이언츠 경기',
      'summary': 'Lotte won 8-3 after ending a losing streak.',
      'directions': <Map<String, dynamic>>[
        _direction('CASUAL_CHAT', 'Casual Chat'),
        _direction('DEBATE', 'Debate'),
        _direction('INTERVIEW_QA', 'Interview'),
        _direction('EXPLANATION_PRACTICE', 'Explain'),
      ],
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'Lotte game recap',
          'url': 'https://example.com/sports/lotte',
          'snippet': 'Lotte beat KIA 8-3.',
        },
      ],
      'quality': _quality(),
      'timestamp': '2026-07-02T00:00:00Z',
    },
    'quality': _quality(),
    'retry_guidance': null,
    'example_topics': <String>[],
  };
}

Map<String, dynamic> _direction(String direction, String title) {
  return <String, dynamic>{
    'direction': direction,
    'title': title,
    'description': 'Practice with a $title tone.',
    'first_questions': <String>[
      'What stood out to you?',
      'Which detail would you explain first?',
      'What would you ask a friend about it?',
    ],
  };
}

Map<String, dynamic> _quality({bool isSufficient = true}) {
  return <String, dynamic>{
    'is_sufficient': isSufficient,
    'source_count': isSufficient ? 3 : 1,
    'has_enough_sources': isSufficient,
    'relevance': isSufficient,
    'freshness': isSufficient,
    'specificity': isSufficient,
    'reason': null,
    'retry_suggestion': isSufficient ? null : 'Try a recent game.',
  };
}
