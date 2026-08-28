import 'package:curitalk/features/conversation/domain/conversation_models.dart';

class ConversationAudioFile {
  const ConversationAudioFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}

abstract interface class ConversationRepository {
  Future<MultimodalConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String roleplayDifficulty = 'NORMAL',
    String? searchContext,
    bool includeAudioResponse = true,
  });

  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  });

  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  });

  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = true,
  });

  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = true,
  });
}

abstract interface class CustomFocusConversationRepository {
  Future<MultimodalConversationResponse> startFreeChatWithCustomFocus({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startFreeChatWithAudioAndCustomFocus({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  });
}

abstract interface class ConversationDeletionRepository {
  Future<void> deleteConversation(String conversationId);
}
