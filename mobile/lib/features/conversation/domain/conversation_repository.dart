import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';

class ConversationAudioFile {
  const ConversationAudioFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.latencyTrace,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
  final LatencyTrace? latencyTrace;
}

abstract interface class ConversationRepository {
  Future<MultimodalConversationResponse> startFreeChat({
    String ttsAccent = 'us',
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    String ttsAccent = 'us',
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startRoleplay({
    String ttsAccent = 'us',
    required String roleCharacter,
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
    String ttsAccent = 'us',
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  });

  Future<MultimodalConversationResponse> startFreeChatWithAudioAndCustomFocus({
    String ttsAccent = 'us',
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

abstract interface class UnreadConversationRepository {
  Future<bool> hasUnreadReplies();
  Future<bool> markRepliesRead(String conversationId, List<String> messageIds);
}

abstract interface class SuggestedConversationRepository {
  Future<SuggestedConversationResponse> startSuggestedFreeChat({
    String ttsAccent = 'us',
    required String topicId,
    required String startRequestId,
    bool includeAudioResponse = true,
  });
}
