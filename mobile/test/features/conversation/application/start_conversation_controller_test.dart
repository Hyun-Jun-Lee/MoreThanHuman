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
    expect(repository.lastFreeChatBody, <String, String?>{
      'first_message': 'I liked the game.',
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
  });
}

class _FakeConversationRepository implements ConversationRepository {
  Map<String, String?>? lastFreeChatBody;
  String? lastRoleCharacter;

  @override
  Future<ConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
  }) async {
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
  Future<ConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
  }) async {
    lastRoleCharacter = roleCharacter;
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
}

ConversationResponse _response(ConversationType type) {
  return ConversationResponse(
    conversationId: 'conversation-id',
    messageId: 'message-id',
    conversationType: type,
    response: 'Hello!',
  );
}
