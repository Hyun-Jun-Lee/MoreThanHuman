import 'package:curitalk/features/conversation/domain/conversation_models.dart';

abstract interface class ConversationRepository {
  Future<ConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
  });

  Future<ConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
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
}
