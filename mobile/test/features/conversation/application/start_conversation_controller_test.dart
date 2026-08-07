import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts free chat with topic metadata', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final ConversationResponse? response = await container
        .read(startConversationControllerProvider.notifier)
        .startFreeChat(
          firstMessage: 'I liked the game.',
          searchContext: 'Lotte won 8-3.',
          topic: '롯데 자이언츠 최근 경기',
          conversationDirection: 'CASUAL_CHAT',
          selectedQuestion: 'What stood out?',
        );

    expect(response?.conversationId, 'conversation-id');
    expect(repository.lastFreeChatIncludeAudio, isTrue);
    expect(
      container
          .read(initialAssistantAudioProvider('conversation-id'))
          ?.audio
          ?.format,
      'mp3',
    );
    expect(repository.lastFreeChatBody, <String, String?>{
      'first_message': 'I liked the game.',
      'search_context': 'Lotte won 8-3.',
      'topic': '롯데 자이언츠 최근 경기',
      'conversation_direction': 'CASUAL_CHAT',
      'selected_question': 'What stood out?',
    });
  });

  test('starts free chat with an audio first answer', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final ConversationResponse? response = await container
        .read(startConversationControllerProvider.notifier)
        .startFreeChatWithAudio(
          audioFile: const ConversationAudioFile(
            bytes: <int>[1, 2, 3],
            filename: 'answer.m4a',
            contentType: 'audio/m4a',
          ),
          searchContext: 'Lotte won 8-3.',
          topic: '롯데 자이언츠 최근 경기',
          conversationDirection: 'CASUAL_CHAT',
          selectedQuestion: 'What stood out?',
        );

    expect(response?.conversationId, 'conversation-id');
    expect(repository.lastAudioFilename, 'answer.m4a');
    expect(repository.lastFreeChatAudioIncludeAudio, isTrue);
    expect(repository.lastFreeChatBody, <String, String?>{
      'first_message': null,
      'search_context': 'Lotte won 8-3.',
      'topic': '롯데 자이언츠 최근 경기',
      'conversation_direction': 'CASUAL_CHAT',
      'selected_question': 'What stood out?',
    });
  });

  test('starts roleplay with role character', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(startConversationControllerProvider.notifier)
        .startRoleplay(roleCharacter: 'A cafe barista who asks follow-ups.');

    expect(repository.lastRoleCharacter, 'A cafe barista who asks follow-ups.');
    expect(repository.lastRoleplayIncludeAudio, isTrue);
  });
}

class _FakeConversationRepository implements ConversationRepository {
  Map<String, String?>? lastFreeChatBody;
  String? lastRoleCharacter;
  String? lastAudioFilename;
  bool? lastFreeChatIncludeAudio;
  bool? lastFreeChatAudioIncludeAudio;
  bool? lastRoleplayIncludeAudio;

  @override
  Future<MultimodalConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) async {
    lastFreeChatIncludeAudio = includeAudioResponse;
    lastFreeChatBody = <String, String?>{
      'first_message': firstMessage,
      'search_context': searchContext,
      'topic': topic,
      'conversation_direction': conversationDirection,
      'selected_question': selectedQuestion,
    };
    return _response(ConversationType.freeChat);
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
    lastFreeChatAudioIncludeAudio = includeAudioResponse;
    lastFreeChatBody = <String, String?>{
      'first_message': null,
      'search_context': searchContext,
      'topic': topic,
      'conversation_direction': conversationDirection,
      'selected_question': selectedQuestion,
    };
    return MultimodalConversationResponse(
      conversationId: 'conversation-id',
      messageId: 'message-id',
      conversationType: ConversationType.freeChat,
      response: 'Hello!',
      inputMode: ConversationInputMode.audio,
      transcript: 'I liked the game.',
      audio: VoiceAudioResponse(
        contentType: 'audio/mpeg',
        base64: 'AAA=',
        format: 'mp3',
      ),
    );
  }

  @override
  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
    bool includeAudioResponse = true,
  }) async {
    lastRoleCharacter = roleCharacter;
    lastRoleplayIncludeAudio = includeAudioResponse;
    return _response(ConversationType.rolePlaying);
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

MultimodalConversationResponse _response(ConversationType type) {
  return MultimodalConversationResponse(
    conversationId: 'conversation-id',
    messageId: 'message-id',
    conversationType: type,
    response: 'Hello!',
    inputMode: ConversationInputMode.text,
    audio: VoiceAudioResponse(
      contentType: 'audio/mpeg',
      base64: 'AAA=',
      format: 'mp3',
    ),
  );
}
