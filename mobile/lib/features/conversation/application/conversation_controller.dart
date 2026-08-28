import 'package:curitalk/features/conversation/application/start_conversation_controller.dart';
import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConversationSendFailureReason { textRequestFailed, audioRequestFailed }

enum AssistantAudioStatus { unavailable }

class ConversationState {
  const ConversationState({
    required this.messages,
    this.isSending = false,
    this.failedMessage,
    this.failedAudioFile,
    this.failureReason,
    this.assistantAudioStatus,
    this.autoPlayAudioMessageIds = const <String>{},
  });

  const ConversationState.empty()
    : messages = const <ConversationMessage>[],
      isSending = false,
      failedMessage = null,
      failedAudioFile = null,
      failureReason = null,
      assistantAudioStatus = null,
      autoPlayAudioMessageIds = const <String>{};

  final List<ConversationMessage> messages;
  final bool isSending;
  final String? failedMessage;
  final ConversationAudioFile? failedAudioFile;
  final ConversationSendFailureReason? failureReason;
  final AssistantAudioStatus? assistantAudioStatus;
  final Set<String> autoPlayAudioMessageIds;

  ConversationState copyWith({
    List<ConversationMessage>? messages,
    bool? isSending,
    String? failedMessage,
    bool clearFailedMessage = false,
    ConversationAudioFile? failedAudioFile,
    bool clearFailedAudioFile = false,
    ConversationSendFailureReason? failureReason,
    AssistantAudioStatus? assistantAudioStatus,
    bool clearAssistantAudioStatus = false,
    Set<String>? autoPlayAudioMessageIds,
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
      failureReason: failureReason,
      assistantAudioStatus: clearAssistantAudioStatus
          ? null
          : assistantAudioStatus ?? this.assistantAudioStatus,
      autoPlayAudioMessageIds:
          autoPlayAudioMessageIds ?? this.autoPlayAudioMessageIds,
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
    final InitialAssistantAudio? initialAudio = ref.read(
      initialAssistantAudioProvider(conversationId),
    );
    final List<ConversationMessage> messages = _attachInitialAssistantAudio(
      page.results,
      initialAudio,
    );
    final int initialAssistantIndex = initialAudio == null
        ? -1
        : _findInitialAssistantIndex(messages, initialAudio.responseText);
    final String? initialAutoPlayMessageId =
        initialAudio?.audio == null || initialAssistantIndex < 0
        ? null
        : messages[initialAssistantIndex].id;
    if (initialAudio != null) {
      ref.read(initialAssistantAudioProvider(conversationId).notifier).clear();
    }
    return ConversationState(
      messages: messages,
      autoPlayAudioMessageIds: initialAutoPlayMessageId == null
          ? const <String>{}
          : <String>{initialAutoPlayMessageId},
    );
  }

  List<ConversationMessage> _attachInitialAssistantAudio(
    List<ConversationMessage> messages,
    InitialAssistantAudio? initialAudio,
  ) {
    if (initialAudio == null) {
      return messages;
    }

    final int assistantIndex = _findInitialAssistantIndex(
      messages,
      initialAudio.responseText,
    );
    if (assistantIndex < 0) {
      return messages;
    }

    return <ConversationMessage>[
      for (int index = 0; index < messages.length; index++)
        index == assistantIndex
            ? messages[index].copyWith(
                audio: initialAudio.audio,
                audioError: initialAudio.audioError,
              )
            : messages[index],
    ];
  }

  int _findInitialAssistantIndex(
    List<ConversationMessage> messages,
    String responseText,
  ) {
    for (int index = messages.length - 1; index >= 0; index--) {
      final ConversationMessage message = messages[index];
      if (message.role != ConversationMessageRole.assistant) {
        continue;
      }
      if (message.content.trim() == responseText.trim()) {
        return index;
      }
    }
    return messages.lastIndexWhere(
      (ConversationMessage message) =>
          message.role == ConversationMessageRole.assistant,
    );
  }

  Future<void> reload() async {
    final ConversationState previous =
        state.value ?? const ConversationState.empty();
    state = AsyncData<ConversationState>(
      previous.copyWith(failureReason: null),
    );
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
        failureReason: null,
        clearAssistantAudioStatus: true,
      ),
    );

    try {
      final MultimodalMessageResponse response = await ref
          .read(conversationRepositoryProvider)
          .sendTextTurn(
            conversationId: conversationId,
            text: normalized,
            includeAudioResponse: true,
          );
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
          failureReason: null,
          assistantAudioStatus: response.audioError == null
              ? null
              : AssistantAudioStatus.unavailable,
          autoPlayAudioMessageIds: response.audio == null
              ? const <String>{}
              : <String>{assistantMessage.id},
        ),
      );
    } on Object catch (_) {
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          failedMessage: normalized,
          clearFailedAudioFile: true,
          failureReason: ConversationSendFailureReason.textRequestFailed,
          clearAssistantAudioStatus: true,
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
        failureReason: null,
        clearAssistantAudioStatus: true,
      ),
    );

    try {
      final MultimodalMessageResponse response = await ref
          .read(conversationRepositoryProvider)
          .sendAudioTurn(
            conversationId: conversationId,
            audioFile: audioFile,
            includeAudioResponse: true,
          );
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
          failureReason: null,
          assistantAudioStatus: response.audioError == null
              ? null
              : AssistantAudioStatus.unavailable,
          autoPlayAudioMessageIds: response.audio == null
              ? const <String>{}
              : <String>{assistantMessage.id},
        ),
      );
    } on Object catch (_) {
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          clearFailedMessage: true,
          failedAudioFile: audioFile,
          failureReason: ConversationSendFailureReason.audioRequestFailed,
          clearAssistantAudioStatus: true,
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

  void consumeAutoPlayAudio(String messageId) {
    final ConversationState? current = state.value;
    if (current == null ||
        !current.autoPlayAudioMessageIds.contains(messageId)) {
      return;
    }
    state = AsyncData<ConversationState>(
      current.copyWith(
        autoPlayAudioMessageIds: <String>{...current.autoPlayAudioMessageIds}
          ..remove(messageId),
      ),
    );
  }
}

final conversationControllerProvider =
    AsyncNotifierProvider.family<
      ConversationController,
      ConversationState,
      String
    >(ConversationController.new);
