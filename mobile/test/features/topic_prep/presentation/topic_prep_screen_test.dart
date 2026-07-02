import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ready state shows summary, sources, and default question', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(repository: _FakeTopicPrepRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Lotte won 8-3.'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('CASUAL CHAT'), findsOneWidget);
    expect(find.text('What stood out in the game?'), findsOneWidget);
    expect(find.bySemanticsLabel('Source: Lotte recap'), findsOneWidget);
  });

  testWidgets('changing direction swaps first question options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(repository: _FakeTopicPrepRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DEBATE'));
    await tester.pumpAndSettle();

    expect(find.text('Was the result convincing?'), findsOneWidget);
    expect(find.text('What stood out in the game?'), findsNothing);
  });

  testWidgets('low-quality state can retry with an example topic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        initialLocation:
            '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent('too broad')}',
        repository: _FakeTopicPrepRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try a more specific topic.'), findsOneWidget);

    await tester.tap(find.text('최근 롯데 자이언츠 경기'));
    await tester.pumpAndSettle();

    expect(find.text('Lotte won 8-3.'), findsOneWidget);
  });

  testWidgets('error state can retry the same topic', (
    WidgetTester tester,
  ) async {
    final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository(
      failFirstTopic: 'flaky topic',
    );
    await tester.pumpWidget(
      _app(
        initialLocation:
            '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent('flaky topic')}',
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not prepare this topic.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Lotte won 8-3.'), findsOneWidget);
    expect(repository.topics, <String>['flaky topic', 'flaky topic']);
  });
}

Widget _app({
  required TopicPrepRepository repository,
  String initialLocation = '${AppRoute.topicPrep}?topic=recent%20lotte',
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.topicInput,
        builder: (_, GoRouterState state) {
          return TopicInputScreen(
            initialTopic: state.uri.queryParameters['topic'],
          );
        },
      ),
      GoRoute(
        path: AppRoute.topicPrep,
        builder: (_, GoRouterState state) {
          return TopicPrepScreen(
            initialTopic: state.uri.queryParameters['topic']!,
          );
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [topicPrepRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

class _FakeTopicPrepRepository implements TopicPrepRepository {
  _FakeTopicPrepRepository({this.failFirstTopic});

  final String? failFirstTopic;
  final List<String> topics = <String>[];

  @override
  Future<TopicPrepResult> prepareTopic(String topic) async {
    topics.add(topic);
    if (topic == failFirstTopic &&
        topics.where((value) => value == topic).length == 1) {
      throw StateError('Temporary failure');
    }
    if (topic == 'too broad') {
      return TopicPrepResult(
        ready: false,
        card: null,
        quality: _quality(isSufficient: false),
        retryGuidance: 'Try a more specific topic.',
        exampleTopics: const <String>['최근 롯데 자이언츠 경기'],
      );
    }
    return TopicPrepResult(
      ready: true,
      card: TopicPrepCard(
        topic: topic,
        summary: 'Lotte won 8-3.',
        directions: <TopicPrepDirection>[
          _direction(TopicPrepDirectionType.casualChat, 'Casual Chat', <String>[
            'What stood out in the game?',
            'Which player caught your eye?',
            'How would you explain the result?',
          ]),
          _direction(TopicPrepDirectionType.debate, 'Debate', <String>[
            'Was the result convincing?',
            'Which side has the stronger argument?',
            'What would critics say?',
          ]),
          _direction(TopicPrepDirectionType.interviewQa, 'Interview', <String>[
            'What would you ask the manager?',
            'How would you interview a player?',
            'What detail needs a follow-up?',
          ]),
          _direction(
            TopicPrepDirectionType.explanationPractice,
            'Explain',
            <String>[
              'How would you explain this to a friend?',
              'What background matters most?',
              'What happened first?',
            ],
          ),
        ],
        sources: const <SearchSource>[
          SearchSource(
            title: 'Lotte recap',
            url: 'https://example.com/sports/lotte',
            snippet: 'Lotte beat KIA.',
          ),
        ],
        quality: _quality(),
        timestamp: DateTime.utc(2026, 7, 2),
      ),
      quality: _quality(),
      exampleTopics: const <String>[],
    );
  }
}

TopicPrepDirection _direction(
  TopicPrepDirectionType type,
  String title,
  List<String> questions,
) {
  return TopicPrepDirection(
    direction: type,
    title: title,
    description: '$title practice',
    firstQuestions: questions,
  );
}

TopicPrepQuality _quality({bool isSufficient = true}) {
  return TopicPrepQuality(
    isSufficient: isSufficient,
    sourceCount: isSufficient ? 3 : 1,
    hasEnoughSources: isSufficient,
    relevance: isSufficient,
    freshness: isSufficient,
    specificity: isSufficient,
  );
}
