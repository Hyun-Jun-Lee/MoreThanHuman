import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads messages and refreshes after send', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final ConversationState initial = await container.read(
      conversationControllerProvider('conversation-id').future,
    );
    expect(initial.messages.single.content, 'Hello!');

    await container
        .read(conversationControllerProvider('conversation-id').notifier)
        .send('I was surprise.');
    final ConversationState state = container
        .read(conversationControllerProvider('conversation-id'))
        .value!;

    expect(repository.sentTextTurns, <String>['I was surprise.']);
    expect(repository.listCallCount, 2);
    expect(state.isSending, isFalse);
    expect(state.messages.last.content, 'Canonical response');
  });

  test('keeps retry target when send fails', () async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      failSend: true,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(
      conversationControllerProvider('conversation-id').future,
    );

    await container
        .read(conversationControllerProvider('conversation-id').notifier)
        .send('Retry me');
    final ConversationState state = container
        .read(conversationControllerProvider('conversation-id'))
        .value!;

    expect(state.failedMessage, 'Retry me');
    expect(state.errorMessage, 'Message could not be sent.');
  });

  test(
    'uses transcript as the user message after audio send succeeds',
    () async {
      final _FakeConversationRepository repository =
          _FakeConversationRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(
        conversationControllerProvider('conversation-id').future,
      );

      await container
          .read(conversationControllerProvider('conversation-id').notifier)
          .sendAudio(
            const ConversationAudioFile(
              bytes: <int>[1, 2, 3],
              filename: 'recording.webm',
              contentType: 'audio/webm',
            ),
          );
      final ConversationState state = container
          .read(conversationControllerProvider('conversation-id'))
          .value!;

      expect(repository.sentAudioFilenames, <String>['recording.webm']);
      expect(state.isSending, isFalse);
      expect(
        state.messages[state.messages.length - 2].content,
        'Audio transcript',
      );
      expect(state.messages.last.content, 'AI response');
    },
  );

  test('keeps audio retry target when audio send fails', () async {
    final _FakeConversationRepository repository = _FakeConversationRepository(
      failAudioSend: true,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(
      conversationControllerProvider('conversation-id').future,
    );

    await container
        .read(conversationControllerProvider('conversation-id').notifier)
        .sendAudio(
          const ConversationAudioFile(
            bytes: <int>[1, 2, 3],
            filename: 'retry.webm',
            contentType: 'audio/webm',
          ),
        );
    final ConversationState state = container
        .read(conversationControllerProvider('conversation-id'))
        .value!;

    expect(state.failedAudioFile?.filename, 'retry.webm');
    expect(state.failedMessage, isNull);
    expect(state.errorMessage, 'Voice message could not be sent.');
  });
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.failSend = false,
    this.failAudioSend = false,
  });

  final bool failSend;
  final bool failAudioSend;
  final List<String> sentTextTurns = <String>[];
  final List<String> sentMessages = <String>[];
  final List<String> sentAudioFilenames = <String>[];
  int listCallCount = 0;

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    listCallCount++;
    final List<ConversationMessage> messages = listCallCount == 1
        ? <ConversationMessage>[
            _message(
              'assistant-1',
              ConversationMessageRole.assistant,
              'Hello!',
            ),
          ]
        : <ConversationMessage>[
            _message(
              'assistant-1',
              ConversationMessageRole.assistant,
              'Hello!',
            ),
            _message('user-1', ConversationMessageRole.user, 'I was surprise.'),
            _message(
              'assistant-2',
              ConversationMessageRole.assistant,
              'Canonical response',
            ),
          ];
    return PaginatedMessages(
      results: messages,
      pagination: Pagination(
        limit: limit,
        offset: offset,
        totalCount: messages.length,
        hasMore: false,
      ),
    );
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    sentMessages.add(message);
    if (failSend) {
      throw StateError('Network failure');
    }
    return const MessageResponse(
      messageId: 'user-1',
      response: 'AI response',
      turnCount: 2,
    );
  }

  @override
  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = false,
  }) async {
    sentTextTurns.add(text);
    if (failSend) {
      throw StateError('Network failure');
    }
    return MultimodalMessageResponse(
      messageId: 'user-1',
      response: 'AI response',
      turnCount: 2,
      inputMode: ConversationInputMode.text,
      transcript: text,
    );
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = false,
  }) async {
    sentAudioFilenames.add(audioFile.filename);
    if (failAudioSend) {
      throw StateError('Network failure');
    }
    return const MultimodalMessageResponse(
      messageId: 'user-audio-1',
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
  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = false,
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

ConversationMessage _message(
  String id,
  ConversationMessageRole role,
  String content,
) {
  return ConversationMessage(
    id: id,
    conversationId: 'conversation-id',
    role: role,
    content: content,
    createdAt: DateTime.utc(2026, 7, 2),
  );
}
