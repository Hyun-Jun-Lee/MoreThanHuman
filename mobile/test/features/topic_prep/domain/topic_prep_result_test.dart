import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a ready topic prep result', () {
    final TopicPrepResult result = TopicPrepResult.fromJson(_readyResult());

    expect(result.ready, isTrue);
    expect(result.card?.summary, 'Lotte won 8-3 after ending a losing streak.');
    expect(result.card?.sources.first.title, 'Lotte game recap');
    expect(result.card?.directions, hasLength(3));
    expect(
      result.card?.directions.first.direction,
      TopicPrepDirectionType.casualChat,
    );
    expect(result.card?.directions.first.firstQuestions, hasLength(3));
    expect(
      result.card?.directions.first.firstQuestionTranslations.first,
      '무엇이 눈에 띄었나요?',
    );
    expect(result.language.nativeLanguage, LearningLanguageCode.zh);
    expect(result.language.targetLanguage, LearningLanguageCode.ko);
  });

  test('parses a ready card when search was skipped', () {
    final Map<String, dynamic> json = _readyResult();
    final Map<String, dynamic> card = json['card']! as Map<String, dynamic>;
    json['search_required'] = false;
    json['quality'] = <String, dynamic>{
      ..._quality(),
      'source_count': 0,
      'has_enough_sources': false,
    };
    card['sources'] = <Map<String, dynamic>>[];
    card['quality'] = json['quality'];

    final TopicPrepResult result = TopicPrepResult.fromJson(json);

    expect(result.ready, isTrue);
    expect(result.card?.sources, isEmpty);
    expect(result.quality.sourceCount, 0);
    expect(result.quality.hasEnoughSources, isFalse);
  });

  test('accepts an older direction without translations', () {
    final Map<String, dynamic> json = _readyResult();
    final List<dynamic> directions =
        (json['card']! as Map<String, dynamic>)['directions']! as List<dynamic>;
    (directions.first as Map<String, dynamic>).remove(
      'first_question_translations',
    );

    final TopicPrepResult result = TopicPrepResult.fromJson(json);

    expect(result.card?.directions.first.firstQuestionTranslations, isEmpty);
  });

  test('accepts an empty translation list from an older server', () {
    final Map<String, dynamic> json = _readyResult();
    final List<dynamic> directions =
        (json['card']! as Map<String, dynamic>)['directions']! as List<dynamic>;
    (directions.first as Map<String, dynamic>)['first_question_translations'] =
        <String>[];

    final TopicPrepResult result = TopicPrepResult.fromJson(json);

    expect(result.card?.directions.first.firstQuestionTranslations, isEmpty);
  });

  test('parses translated custom focus questions', () {
    final CustomFocusQuestions result = CustomFocusQuestions.fromJson(
      <String, dynamic>{
        'ready': true,
        'custom_focus': 'the bullpen',
        'first_questions': <String>[
          'Question 1?',
          'Question 2?',
          'Question 3?',
        ],
        'first_question_translations': <String>['번역 1?', '번역 2?', '번역 3?'],
      },
    );

    expect(result.firstQuestionTranslations, <String>[
      '번역 1?',
      '번역 2?',
      '번역 3?',
    ]);
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
    'first_question_translations': <String>[
      '무엇이 눈에 띄었나요?',
      '어떤 부분을 먼저 설명하겠어요?',
      '친구에게 무엇을 물어보겠어요?',
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
