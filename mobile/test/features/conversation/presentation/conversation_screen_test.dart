import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('explicit back button returns to Home when stack is empty', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.conversationPath('conversation-id'),
      routes: <RouteBase>[
        GoRoute(path: AppRoute.home, builder: (_, _) => const Text('Home')),
        GoRoute(
          path: '${AppRoute.conversation}/:conversationId',
          builder: (_, GoRouterState state) {
            return ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _FakeConversationRepository(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello!'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('voice input records and sends audio turn', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final _FakeConversationAudioRecorder recorder =
        _FakeConversationAudioRecorder();
    final GoRouter router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationAudioRecorderProvider.overrideWithValue(recorder),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    expect(recorder.startCount, 1);
    expect(find.byTooltip('Stop recording'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(recorder.stopCount, 1);
    expect(repository.sentAudioFilenames, <String>['recording.m4a']);
    expect(find.text('Audio transcript'), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: AppRoute.conversationPath('conversation-id'),
    routes: <RouteBase>[
      GoRoute(path: AppRoute.home, builder: (_, _) => const Text('Home')),
      GoRoute(
        path: '${AppRoute.conversation}/:conversationId',
        builder: (_, GoRouterState state) {
          return ConversationScreen(
            conversationId: state.pathParameters['conversationId']!,
          );
        },
      ),
    ],
  );
}

class _FakeConversationRepository implements ConversationRepository {
  final List<String> sentAudioFilenames = <String>[];

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return PaginatedMessages(
      results: <ConversationMessage>[
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: conversationId,
          role: ConversationMessageRole.assistant,
          content: 'Hello!',
          createdAt: DateTime.utc(2026, 7, 11),
        ),
      ],
      pagination: Pagination(
        limit: limit,
        offset: offset,
        totalCount: 1,
        hasMore: false,
      ),
    );
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
    bool includeAudioResponse = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = false,
  }) async {
    sentAudioFilenames.add(audioFile.filename);
    return const MultimodalMessageResponse(
      messageId: 'user-audio-id',
      response: 'AI response',
      turnCount: 2,
      inputMode: ConversationInputMode.audio,
      transcript: 'Audio transcript',
    );
  }

  @override
  Future<ConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
  }) {
    throw UnimplementedError();
  }
}

class _FakeConversationAudioRecorder implements ConversationAudioRecorder {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<ConversationAudioFile> stop() async {
    stopCount++;
    return const ConversationAudioFile(
      bytes: <int>[1, 2, 3],
      filename: 'recording.m4a',
      contentType: 'audio/m4a',
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
