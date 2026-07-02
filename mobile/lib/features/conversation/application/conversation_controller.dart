import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationState {
  const ConversationState({
    required this.messages,
    this.isSending = false,
    this.failedMessage,
    this.errorMessage,
  });

  const ConversationState.empty()
    : messages = const <ConversationMessage>[],
      isSending = false,
      failedMessage = null,
      errorMessage = null;

  final List<ConversationMessage> messages;
  final bool isSending;
  final String? failedMessage;
  final String? errorMessage;

  ConversationState copyWith({
    List<ConversationMessage>? messages,
    bool? isSending,
    String? failedMessage,
    bool clearFailedMessage = false,
    String? errorMessage,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      failedMessage: clearFailedMessage
          ? null
          : failedMessage ?? this.failedMessage,
      errorMessage: errorMessage,
    );
  }
}

class ConversationController extends AsyncNotifier<ConversationState> {
  ConversationController(this.conversationId);

  final String conversationId;

  @override
  Future<ConversationState> build() async {
    final PaginatedMessages page = await ref
        .watch(conversationRepositoryProvider)
        .listMessages(conversationId);
    return ConversationState(messages: page.results);
  }

  Future<void> reload() async {
    final ConversationState previous =
        state.value ?? const ConversationState.empty();
    state = AsyncData<ConversationState>(previous.copyWith(errorMessage: null));
    final AsyncValue<ConversationState> next = await AsyncValue.guard(() async {
      final PaginatedMessages page = await ref
          .read(conversationRepositoryProvider)
          .listMessages(conversationId);
      return ConversationState(messages: page.results);
    });
    state = next;
  }

  Future<void> send(String message) async {
    final String normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    final ConversationState previous =
        state.value ?? const ConversationState.empty();
    final ConversationMessage pendingMessage = ConversationMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      role: ConversationMessageRole.user,
      content: normalized,
      createdAt: DateTime.now(),
      isLocalPending: true,
    );

    state = AsyncData<ConversationState>(
      previous.copyWith(
        messages: <ConversationMessage>[...previous.messages, pendingMessage],
        isSending: true,
        clearFailedMessage: true,
        errorMessage: null,
      ),
    );

    try {
      final MessageResponse response = await ref
          .read(conversationRepositoryProvider)
          .sendMessage(conversationId: conversationId, message: normalized);
      final ConversationMessage confirmedUserMessage = pendingMessage.copyWith(
        id: response.messageId,
        grammarFeedback: response.grammarFeedback,
        isLocalPending: false,
      );
      final ConversationMessage assistantMessage = ConversationMessage(
        id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        role: ConversationMessageRole.assistant,
        content: response.response,
        createdAt: DateTime.now(),
      );
      state = AsyncData<ConversationState>(
        previous.copyWith(
          messages: <ConversationMessage>[
            ...previous.messages,
            confirmedUserMessage,
            assistantMessage,
          ],
          isSending: false,
          clearFailedMessage: true,
          errorMessage: null,
        ),
      );
      await reload();
    } on Object catch (_) {
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          failedMessage: normalized,
          errorMessage: 'Message could not be sent.',
        ),
      );
    }
  }

  Future<void> retryFailedMessage() async {
    final String? message = state.value?.failedMessage;
    if (message == null) {
      return;
    }
    await send(message);
  }
}

final conversationControllerProvider =
    AsyncNotifierProvider.family<
      ConversationController,
      ConversationState,
      String
    >(ConversationController.new);
