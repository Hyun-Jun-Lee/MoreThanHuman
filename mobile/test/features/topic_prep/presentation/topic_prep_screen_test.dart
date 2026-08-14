import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/language/language.dart';
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

  testWidgets('first answer starts free-chat conversation', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    await tester.pumpWidget(
      _app(
        repository: _FakeTopicPrepRepository(),
        conversationRepository: conversationRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.bySemanticsLabel('First answer in Korean'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, '오늘 불펜이 좋았어요.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation conversation-id'), findsOneWidget);
    expect(conversationRepository.lastFirstMessage, '오늘 불펜이 좋았어요.');
    expect(conversationRepository.lastDirection, 'CASUAL_CHAT');
    expect(
      conversationRepository.lastSelectedQuestion,
      'What stood out in the game?',
    );
  });

  testWidgets('voice first answer starts free-chat conversation', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    final _FakeConversationAudioRecorder recorder =
        _FakeConversationAudioRecorder();
    await tester.pumpWidget(
      _app(
        repository: _FakeTopicPrepRepository(),
        conversationRepository: conversationRepository,
        recorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Voice input'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Voice input'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();
    await tester.pump(minimumVoiceRecordingDuration);
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('Conversation conversation-id'), findsOneWidget);
    expect(recorder.startCount, 1);
    expect(recorder.stopCount, 1);
    expect(conversationRepository.lastAudioFilename, 'answer.m4a');
    expect(conversationRepository.lastDirection, 'CASUAL_CHAT');
    expect(
      conversationRepository.lastSelectedQuestion,
      'What stood out in the game?',
    );
  });
}

Widget _app({
  required TopicPrepRepository repository,
  ConversationRepository? conversationRepository,
  ConversationAudioRecorder? recorder,
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
      GoRoute(
        path: '${AppRoute.conversation}/:conversationId',
        builder: (_, GoRouterState state) {
          return Text('Conversation ${state.pathParameters['conversationId']}');
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      topicPrepRepositoryProvider.overrideWithValue(repository),
      if (conversationRepository != null)
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
      if (recorder != null)
        conversationAudioRecorderProvider.overrideWithValue(recorder),
    ],
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
        language: _koreanPracticeLanguage,
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
      language: _koreanPracticeLanguage,
      exampleTopics: const <String>[],
    );
  }
}

const LearningLanguageContext _koreanPracticeLanguage = LearningLanguageContext(
  nativeLanguage: LearningLanguageCode.en,
  targetLanguage: LearningLanguageCode.ko,
  feedbackLanguage: LearningLanguageCode.en,
);

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

class _FakeConversationRepository implements ConversationRepository {
  String? lastFirstMessage;
  String? lastDirection;
  String? lastSelectedQuestion;
  String? lastAudioFilename;

  @override
  Future<MultimodalConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) async {
    lastFirstMessage = firstMessage;
    lastDirection = conversationDirection;
    lastSelectedQuestion = selectedQuestion;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.text,
    );
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) async {
    lastAudioFilename = audioFile.filename;
    lastDirection = conversationDirection;
    lastSelectedQuestion = selectedQuestion;
    return const MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Great. Tell me more.',
      inputMode: ConversationInputMode.audio,
      transcript: '오늘 불펜이 좋았어요.',
    );
  }

  @override
  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }
}

class _FakeConversationAudioRecorder implements ConversationAudioRecorder {
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<ConversationAudioFile> stop() async {
    stopCount++;
    return const ConversationAudioFile(
      bytes: <int>[1, 2, 3],
      filename: 'answer.m4a',
      contentType: 'audio/m4a',
    );
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() async {}
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
