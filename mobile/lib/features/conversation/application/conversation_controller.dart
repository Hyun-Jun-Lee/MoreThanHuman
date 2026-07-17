import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationState {
  const ConversationState({
    required this.messages,
    this.isSending = false,
    this.failedMessage,
    this.failedAudioFile,
    this.errorMessage,
    this.audioErrorMessage,
  });

  const ConversationState.empty()
    : messages = const <ConversationMessage>[],
      isSending = false,
      failedMessage = null,
      failedAudioFile = null,
      errorMessage = null,
      audioErrorMessage = null;

  final List<ConversationMessage> messages;
  final bool isSending;
  final String? failedMessage;
  final ConversationAudioFile? failedAudioFile;
  final String? errorMessage;
  final String? audioErrorMessage;

  ConversationState copyWith({
    List<ConversationMessage>? messages,
    bool? isSending,
    String? failedMessage,
    bool clearFailedMessage = false,
    ConversationAudioFile? failedAudioFile,
    bool clearFailedAudioFile = false,
    String? errorMessage,
    String? audioErrorMessage,
    bool clearAudioErrorMessage = false,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      failedMessage: clearFailedMessage
          ? null
          : failedMessage ?? this.failedMessage,
      failedAudioFile: clearFailedAudioFile
          ? null
          : failedAudioFile ?? this.failedAudioFile,
      errorMessage: errorMessage,
      audioErrorMessage: clearAudioErrorMessage
          ? null
          : audioErrorMessage ?? this.audioErrorMessage,
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
    if (state.value?.isSending == true) {
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
        clearFailedAudioFile: true,
        errorMessage: null,
        clearAudioErrorMessage: true,
      ),
    );

    try {
      final MultimodalMessageResponse response = await ref
          .read(conversationRepositoryProvider)
          .sendTextTurn(conversationId: conversationId, text: normalized);
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
        audio: response.audio,
        audioError: response.audioError,
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
          clearFailedAudioFile: true,
          errorMessage: null,
          audioErrorMessage: response.audioError?.message,
        ),
      );
      await reload();
    } on Object catch (_) {
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          failedMessage: normalized,
          clearFailedAudioFile: true,
          errorMessage: 'Message could not be sent.',
          clearAudioErrorMessage: true,
        ),
      );
    }
  }

  Future<void> sendAudio(ConversationAudioFile audioFile) async {
    if (audioFile.bytes.isEmpty || state.value?.isSending == true) {
      return;
    }

    final ConversationState previous =
        state.value ?? const ConversationState.empty();
    state = AsyncData<ConversationState>(
      previous.copyWith(
        isSending: true,
        clearFailedMessage: true,
        clearFailedAudioFile: true,
        errorMessage: null,
        clearAudioErrorMessage: true,
      ),
    );

    try {
      final MultimodalMessageResponse response = await ref
          .read(conversationRepositoryProvider)
          .sendAudioTurn(conversationId: conversationId, audioFile: audioFile);
      final String transcript = response.transcript?.trim() ?? '';
      final ConversationMessage userMessage = ConversationMessage(
        id: response.messageId,
        conversationId: conversationId,
        role: ConversationMessageRole.user,
        content: transcript,
        createdAt: DateTime.now(),
        grammarFeedback: response.grammarFeedback,
      );
      final ConversationMessage assistantMessage = ConversationMessage(
        id: 'local-assistant-${DateTime.now().microsecondsSinceEpoch}',
        conversationId: conversationId,
        role: ConversationMessageRole.assistant,
        content: response.response,
        createdAt: DateTime.now(),
        audio: response.audio,
        audioError: response.audioError,
      );
      state = AsyncData<ConversationState>(
        previous.copyWith(
          messages: <ConversationMessage>[
            ...previous.messages,
            userMessage,
            assistantMessage,
          ],
          isSending: false,
          clearFailedMessage: true,
          clearFailedAudioFile: true,
          errorMessage: null,
          audioErrorMessage: response.audioError?.message,
        ),
      );
    } on Object catch (_) {
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          clearFailedMessage: true,
          failedAudioFile: audioFile,
          errorMessage: 'Voice message could not be sent.',
          clearAudioErrorMessage: true,
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

  Future<void> retryFailedAudio() async {
    final ConversationAudioFile? audioFile = state.value?.failedAudioFile;
    if (audioFile == null) {
      return;
    }
    await sendAudio(audioFile);
  }
}

final conversationControllerProvider =
    AsyncNotifierProvider.family<
      ConversationController,
      ConversationState,
      String
    >(ConversationController.new);
