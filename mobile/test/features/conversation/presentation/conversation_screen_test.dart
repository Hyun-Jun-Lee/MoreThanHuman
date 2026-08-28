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
    final _FakeConversationAudioPlayer audioPlayer =
        _FakeConversationAudioPlayer();
    final GoRouter router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationAudioRecorderProvider.overrideWithValue(recorder),
          conversationAudioPlayerProvider.overrideWithValue(audioPlayer),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    expect(recorder.startCount, 1);
    expect(find.byTooltip('Stop recording'), findsOneWidget);
    expect(find.text('Recording 0:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Recording 0:02'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(recorder.stopCount, 1);
    expect(repository.sentAudioFilenames, <String>['recording.m4a']);
    expect(repository.sentAudioIncludeAudio, <bool>[true]);
    expect(find.text('Audio transcript'), findsOneWidget);
    expect(audioPlayer.playCount, 1);
    expect(find.text('Replay response'), findsOneWidget);
  });

  testWidgets('voice input can cancel recording without upload', (
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
    await tester.tap(find.byTooltip('Cancel recording'));
    await tester.pumpAndSettle();

    expect(recorder.cancelCount, 1);
    expect(recorder.stopCount, 0);
    expect(repository.sentAudioFilenames, isEmpty);
    expect(find.byTooltip('Voice input'), findsOneWidget);
  });

  testWidgets(
    'voice input shows permission denial without recording controls',
    (WidgetTester tester) async {
      final _FakeConversationAudioRecorder recorder =
          _FakeConversationAudioRecorder(
            startError: const ConversationAudioException(
              'Microphone permission is required.',
              reason: ConversationAudioExceptionReason.permissionDenied,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(
              _FakeConversationRepository(),
            ),
            conversationAudioRecorderProvider.overrideWithValue(recorder),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: _router(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Voice input'));
      await tester.pumpAndSettle();

      expect(find.text('Microphone permission is required.'), findsOneWidget);
      expect(find.byTooltip('Stop recording'), findsNothing);
    },
  );

  testWidgets('empty voice recording does not upload audio', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final _FakeConversationAudioRecorder recorder =
        _FakeConversationAudioRecorder(
          audioFile: const ConversationAudioFile(
            bytes: <int>[],
            filename: 'empty.m4a',
            contentType: 'audio/m4a',
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationAudioRecorderProvider.overrideWithValue(recorder),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await tester.pump(minimumVoiceRecordingDuration);
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not hear enough audio. Try speaking a little longer.'),
      findsOneWidget,
    );
    expect(repository.sentAudioFilenames, isEmpty);
  });

  testWidgets(
    'short voice recording shows recognition guidance without upload',
    (WidgetTester tester) async {
      final _FakeConversationRepository repository =
          _FakeConversationRepository();
      final _FakeConversationAudioRecorder recorder =
          _FakeConversationAudioRecorder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationRepositoryProvider.overrideWithValue(repository),
            conversationAudioRecorderProvider.overrideWithValue(recorder),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: _router(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Voice input'));
      await tester.pump();
      await tester.tap(find.byTooltip('Stop recording'));
      await tester.pumpAndSettle();

      expect(recorder.stopCount, 1);
      expect(
        find.text('We could not hear enough audio. Try speaking a little longer.'),
        findsOneWidget,
      );
      expect(repository.sentAudioFilenames, isEmpty);
    },
  );

  testWidgets('voice upload failure shows retry card without recorder error', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      failAudioSend: true,
    );
    final _FakeConversationAudioRecorder recorder =
        _FakeConversationAudioRecorder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationAudioRecorderProvider.overrideWithValue(recorder),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    await tester.pump(minimumVoiceRecordingDuration);
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pumpAndSettle();

    expect(
      find.text('Your voice message could not be sent. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.text('We could not hear enough audio. Try speaking a little longer.'),
      findsNothing,
    );
    expect(repository.sentAudioFilenames, <String>['recording.m4a']);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.sentAudioFilenames, <String>[
      'recording.m4a',
      'recording.m4a',
    ]);
  });

  testWidgets('typed send still works without voice state', (
    WidgetTester tester,
  ) async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final _FakeConversationAudioPlayer audioPlayer =
        _FakeConversationAudioPlayer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationAudioPlayerProvider.overrideWithValue(audioPlayer),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'I need coffee.');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(repository.sentTextTurns, <String>['I need coffee.']);
    expect(repository.sentTextIncludeAudio, <bool>[true]);
    expect(audioPlayer.playCount, 1);
    expect(find.text('Replay response'), findsOneWidget);
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
  _FakeConversationRepository({this.failAudioSend = false});

  final bool failAudioSend;
  final List<String> sentAudioFilenames = <String>[];
  final List<String> sentTextTurns = <String>[];
  final List<bool> sentAudioIncludeAudio = <bool>[];
  final List<bool> sentTextIncludeAudio = <bool>[];

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
    bool includeAudioResponse = true,
  }) async {
    sentTextTurns.add(text);
    sentTextIncludeAudio.add(includeAudioResponse);
    return MultimodalMessageResponse(
      messageId: 'user-text-id',
      response: 'AI response',
      turnCount: 2,
      inputMode: ConversationInputMode.text,
      transcript: text,
      audio: const VoiceAudioResponse(
        contentType: 'audio/mpeg',
        base64: 'AAA=',
        format: 'mp3',
      ),
    );
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = true,
  }) async {
    sentAudioFilenames.add(audioFile.filename);
    sentAudioIncludeAudio.add(includeAudioResponse);
    if (failAudioSend) {
      throw StateError('Network failure');
    }
    return const MultimodalMessageResponse(
      messageId: 'user-audio-id',
      response: 'AI response',
      turnCount: 2,
      inputMode: ConversationInputMode.audio,
      transcript: 'Audio transcript',
      audio: VoiceAudioResponse(
        contentType: 'audio/mpeg',
        base64: 'AAA=',
        format: 'mp3',
      ),
    );
  }

  @override
  Future<MultimodalConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String roleplayDifficulty = 'NORMAL',
    String? searchContext,
    bool includeAudioResponse = true,
  }) {
    throw UnimplementedError();
  }
}

class _FakeConversationAudioRecorder implements ConversationAudioRecorder {
  _FakeConversationAudioRecorder({this.startError, this.audioFile});

  final ConversationAudioException? startError;
  final ConversationAudioFile? audioFile;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  @override
  Future<void> start() async {
    startCount++;
    final ConversationAudioException? error = startError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<ConversationAudioFile> stop() async {
    stopCount++;
    return audioFile ??
        const ConversationAudioFile(
          bytes: <int>[1, 2, 3],
          filename: 'recording.m4a',
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

class _FakeConversationAudioPlayer implements ConversationAudioPlayer {
  int playCount = 0;

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    playCount++;
  }

  @override
  Future<void> dispose() async {}
}
