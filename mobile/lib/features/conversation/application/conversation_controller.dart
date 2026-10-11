import 'dart:async';
import 'dart:collection';

import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/features/conversation/application/conversation_audio_services.dart';
import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/data/conversation_stream_api.dart';
import 'package:curitalk/features/conversation/application/start_conversation_controller.dart';
import 'package:curitalk/features/conversation/application/stream_sentence_boundary.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

enum ConversationSendFailureReason {
  textRequestFailed,
  audioRequestFailed,
  turnLimitReached,
  conversationLocked,
}

enum AssistantAudioStatus { unavailable }

class ConversationState {
  const ConversationState({
    required this.messages,
    this.isSending = false,
    this.failedMessage,
    this.failedAudioFile,
    this.failureReason,
    this.assistantAudioStatus,
    this.failedTurnId,
    this.audioRetryMessageId,
    this.pendingTurnId,
    this.pendingRequestId,
    this.unconfirmedText,
    this.unconfirmedAudioFile,
    this.autoPlayAudioMessageIds = const <String>{},
    this.revealingAssistantId,
    this.minVisibleAssistantChars = 0,
    this.oldestOffset = 0,
    this.isLoadingOlder = false,
    this.olderMessagesFailed = false,
  });

  const ConversationState.empty()
    : messages = const <ConversationMessage>[],
      isSending = false,
      failedMessage = null,
      failedAudioFile = null,
      failureReason = null,
      assistantAudioStatus = null,
      failedTurnId = null,
      audioRetryMessageId = null,
      pendingTurnId = null,
      pendingRequestId = null,
      unconfirmedText = null,
      unconfirmedAudioFile = null,
      autoPlayAudioMessageIds = const <String>{},
      revealingAssistantId = null,
      minVisibleAssistantChars = 0,
      oldestOffset = 0,
      isLoadingOlder = false,
      olderMessagesFailed = false;

  final List<ConversationMessage> messages;
  final bool isSending;
  final String? failedMessage;
  final ConversationAudioFile? failedAudioFile;
  final ConversationSendFailureReason? failureReason;
  final AssistantAudioStatus? assistantAudioStatus;
  final String? failedTurnId;
  final String? audioRetryMessageId;
  final String? pendingTurnId;
  final String? pendingRequestId;
  final String? unconfirmedText;
  final ConversationAudioFile? unconfirmedAudioFile;
  final Set<String> autoPlayAudioMessageIds;
  final String? revealingAssistantId;
  final int minVisibleAssistantChars;
  final int oldestOffset;
  final bool isLoadingOlder;
  final bool olderMessagesFailed;

  bool get hasOlderMessages => oldestOffset > 0;

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
    String? failedTurnId,
    bool clearFailedTurnId = false,
    String? audioRetryMessageId,
    bool clearAudioRetryMessageId = false,
    String? pendingTurnId,
    bool clearPendingTurnId = false,
    String? pendingRequestId,
    bool clearPendingRequestId = false,
    String? unconfirmedText,
    bool clearUnconfirmedText = false,
    ConversationAudioFile? unconfirmedAudioFile,
    bool clearUnconfirmedAudioFile = false,
    Set<String>? autoPlayAudioMessageIds,
    String? revealingAssistantId,
    bool clearRevealingAssistant = false,
    int? minVisibleAssistantChars,
    int? oldestOffset,
    bool? isLoadingOlder,
    bool? olderMessagesFailed,
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
      failedTurnId: clearFailedTurnId
          ? null
          : failedTurnId ?? this.failedTurnId,
      audioRetryMessageId: clearAudioRetryMessageId
          ? null
          : audioRetryMessageId ?? this.audioRetryMessageId,
      pendingTurnId: clearPendingTurnId
          ? null
          : pendingTurnId ?? this.pendingTurnId,
      pendingRequestId: clearPendingRequestId
          ? null
          : pendingRequestId ?? this.pendingRequestId,
      unconfirmedText: clearUnconfirmedText
          ? null
          : unconfirmedText ?? this.unconfirmedText,
      unconfirmedAudioFile: clearUnconfirmedAudioFile
          ? null
          : unconfirmedAudioFile ?? this.unconfirmedAudioFile,
      autoPlayAudioMessageIds:
          autoPlayAudioMessageIds ?? this.autoPlayAudioMessageIds,
      revealingAssistantId: clearRevealingAssistant
          ? null
          : revealingAssistantId ?? this.revealingAssistantId,
      minVisibleAssistantChars:
          minVisibleAssistantChars ?? this.minVisibleAssistantChars,
      oldestOffset: oldestOffset ?? this.oldestOffset,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      olderMessagesFailed: olderMessagesFailed ?? this.olderMessagesFailed,
    );
  }
}

class ConversationController extends AsyncNotifier<ConversationState> {
  ConversationController(this.conversationId);

  final String conversationId;
  static const int _pageSize = 40;
  CancelToken? _activeStreamToken;
  String? _activeReplayMessageId;
  final Queue<({VoiceAudioResponse audio, int? textEnd})> _audioQueue =
      Queue<({VoiceAudioResponse audio, int? textEnd})>();
  bool _playingAudio = false;
  int _audioGeneration = 0;
  bool _localPlaybackFailed = false;
  LatencyTrace? _activeStreamTrace;
  String? _activeStreamAssistantId;
  bool _firstTextFrameSeen = false;
  int _visibleAssistantChars = 0;
  int _lastAudioTextEnd = 0;
  int _releasedAssistantChars = 0;
  String _bufferedAssistantText = '';
  String? _completedAssistantText;
  String? _completedAssistantId;
  Completer<void>? _assistantFrameWaiter;
  int _assistantFrameThreshold = 0;

  void onAssistantTextFrameReady(String assistantMessageId, int visibleChars) {
    if (_activeStreamAssistantId != assistantMessageId) {
      return;
    }
    if (!_firstTextFrameSeen && visibleChars > 0) {
      _firstTextFrameSeen = true;
      _activeStreamTrace?.mark('first_text_frame');
    }
    if (visibleChars > _visibleAssistantChars) {
      _visibleAssistantChars = visibleChars;
      if (visibleChars > _assistantFrameThreshold) {
        final waiter = _assistantFrameWaiter;
        if (waiter != null && !waiter.isCompleted) waiter.complete();
      }
    }
    final current = state.value;
    if (current != null &&
        !current.isSending &&
        current.revealingAssistantId == assistantMessageId &&
        _completedAssistantText != null &&
        _releasedAssistantChars >= _completedAssistantText!.length &&
        _audioQueue.isEmpty &&
        !_playingAudio &&
        current.messages.any(
          (message) =>
              message.id == assistantMessageId &&
              message.content.length <= visibleChars,
        )) {
      state = AsyncData(current.copyWith(clearRevealingAssistant: true));
    }
  }

  Future<void> cancelActiveStream() async {
    final completedText = _completedAssistantText;
    if (completedText != null &&
        _releasedAssistantChars < completedText.length) {
      _showAssistantPrefix(completedText.length);
    }
    _activeStreamToken?.cancel('Conversation screen closed');
    _activeStreamToken = null;
    _activeReplayMessageId = null;
    _audioGeneration++;
    _audioQueue.clear();
    _activeStreamTrace = null;
    _activeStreamAssistantId = null;
    _firstTextFrameSeen = false;
    _visibleAssistantChars = 0;
    _lastAudioTextEnd = 0;
    _releasedAssistantChars = 0;
    _bufferedAssistantText = '';
    _completedAssistantText = null;
    _completedAssistantId = null;
    if (_assistantFrameWaiter?.isCompleted == false) {
      _assistantFrameWaiter!.complete();
    }
    _assistantFrameWaiter = null;
    try {
      await ref.read(conversationAudioPlayerProvider).stop();
    } on Object {
      // 화면 종료는 재생 장치 오류와 관계없이 진행해요.
    }
  }

  Future<PaginatedMessages> _loadLatestPage(
    ConversationRepository repository,
  ) async {
    final PaginatedMessages first = await repository.listMessages(
      conversationId,
      limit: _pageSize,
    );
    if (first.pagination.totalCount <= _pageSize) return first;
    return repository.listMessages(
      conversationId,
      limit: _pageSize,
      offset: first.pagination.totalCount - _pageSize,
    );
  }

  @override
  Future<ConversationState> build() async {
    ref.onDispose(() => _activeStreamToken?.cancel('Conversation closed'));
    final repository = ref.watch(conversationRepositoryProvider);
    final PaginatedMessages page = await _loadLatestPage(repository);
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
    final recovery = repository is ApiConversationRepository
        ? await _loadStreamRecovery(repository)
        : const <StreamTurnStatus>[];
    return ConversationState(
      messages: messages,
      oldestOffset: page.pagination.offset,
      autoPlayAudioMessageIds: initialAutoPlayMessageId == null
          ? const <String>{}
          : <String>{initialAutoPlayMessageId},
      failedTurnId: _firstTurn(recovery, 'failed')?.turnId,
      pendingTurnId: _firstTurn(recovery, 'pending')?.turnId,
      audioRetryMessageId: recovery
          .where(
            (turn) =>
                turn.status == 'completed' && turn.audioStatus == 'failed',
          )
          .firstOrNull
          ?.assistantMessageId,
      failureReason: _firstTurn(recovery, 'failed') == null
          ? null
          : ConversationSendFailureReason.textRequestFailed,
      assistantAudioStatus:
          recovery.any(
            (turn) =>
                turn.status == 'completed' && turn.audioStatus == 'failed',
          )
          ? AssistantAudioStatus.unavailable
          : null,
    );
  }

  Future<List<StreamTurnStatus>> _loadStreamRecovery(
    ApiConversationRepository repository,
  ) {
    return ConversationStreamApi(
      repository.apiClient,
    ).unresolved(conversationId);
  }

  StreamTurnStatus? _firstTurn(List<StreamTurnStatus> turns, String status) {
    for (final turn in turns) {
      if (turn.status == status) return turn;
    }
    return null;
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
    if (state.isLoading ||
        state.value?.isSending == true ||
        state.value?.isLoadingOlder == true) {
      return;
    }
    state = const AsyncLoading<ConversationState>();
    final AsyncValue<ConversationState> next = await AsyncValue.guard(() async {
      final PaginatedMessages page = await _loadLatestPage(
        ref.read(conversationRepositoryProvider),
      );
      final repository = ref.read(conversationRepositoryProvider);
      final recovery = repository is ApiConversationRepository
          ? await _loadStreamRecovery(repository)
          : const <StreamTurnStatus>[];
      return ConversationState(
        messages: page.results,
        oldestOffset: page.pagination.offset,
        failedTurnId: _firstTurn(recovery, 'failed')?.turnId,
        pendingTurnId: _firstTurn(recovery, 'pending')?.turnId,
        audioRetryMessageId: recovery
            .where(
              (turn) =>
                  turn.status == 'completed' && turn.audioStatus == 'failed',
            )
            .firstOrNull
            ?.assistantMessageId,
        failureReason: _firstTurn(recovery, 'failed') == null
            ? null
            : ConversationSendFailureReason.textRequestFailed,
        assistantAudioStatus:
            recovery.any(
              (turn) =>
                  turn.status == 'completed' && turn.audioStatus == 'failed',
            )
            ? AssistantAudioStatus.unavailable
            : null,
      );
    });
    if (ref.mounted) state = next;
  }

  Future<void> loadOlderMessages() async {
    final ConversationState? previous = state.value;
    if (previous == null ||
        !previous.hasOlderMessages ||
        previous.isLoadingOlder ||
        previous.isSending) {
      return;
    }
    final int offset = (previous.oldestOffset - _pageSize).clamp(
      0,
      previous.oldestOffset,
    );
    state = AsyncData(
      previous.copyWith(
        isLoadingOlder: true,
        olderMessagesFailed: false,
        failureReason: previous.failureReason,
      ),
    );
    try {
      final PaginatedMessages page = await ref
          .read(conversationRepositoryProvider)
          .listMessages(
            conversationId,
            limit: previous.oldestOffset - offset,
            offset: offset,
          );
      if (!ref.mounted) return;
      if (page.results.isEmpty) throw StateError('Empty history page');
      final ConversationState current = state.requireValue;
      final Set<String> existingIds = current.messages.map((m) => m.id).toSet();
      state = AsyncData(
        current.copyWith(
          messages: [
            ...page.results.where(
              (message) => !existingIds.contains(message.id),
            ),
            ...current.messages,
          ],
          oldestOffset: offset,
          isLoadingOlder: false,
          failureReason: current.failureReason,
        ),
      );
    } on Object {
      if (!ref.mounted) return;
      final ConversationState current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          isLoadingOlder: false,
          olderMessagesFailed: true,
          failureReason: current.failureReason,
        ),
      );
    }
  }

  Future<void> send(String message) async {
    final String normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!state.hasValue ||
        state.value?.isSending == true ||
        state.value?.isLoadingOlder == true ||
        state.value?.failedTurnId != null ||
        state.value?.pendingTurnId != null ||
        state.value?.pendingRequestId != null) {
      return;
    }

    final repository = ref.read(conversationRepositoryProvider);
    if (repository is ApiConversationRepository) {
      await _sendStream(repository, text: normalized);
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
      ref.invalidate(conversationTurnAccessProvider(conversationId));
    } on Object catch (error) {
      final bool limitReached =
          error is ApiException && error.code == 'CONVERSATION_TURNS_FULL';
      final bool locked =
          error is ApiException && error.code == 'CONVERSATION_LOCKED';
      if (limitReached || locked) {
        ref.invalidate(conversationTurnAccessProvider(conversationId));
      }
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          failedMessage: limitReached || locked ? null : normalized,
          clearFailedAudioFile: true,
          failureReason: limitReached
              ? ConversationSendFailureReason.turnLimitReached
              : locked
              ? ConversationSendFailureReason.conversationLocked
              : ConversationSendFailureReason.textRequestFailed,
          clearAssistantAudioStatus: true,
        ),
      );
    }
  }

  Future<void> sendAudio(ConversationAudioFile audioFile) async {
    if (audioFile.bytes.isEmpty ||
        !state.hasValue ||
        state.value?.isSending == true ||
        state.value?.isLoadingOlder == true ||
        state.value?.failedTurnId != null ||
        state.value?.pendingTurnId != null ||
        state.value?.pendingRequestId != null) {
      return;
    }

    final repository = ref.read(conversationRepositoryProvider);
    if (repository is ApiConversationRepository) {
      await _sendStream(repository, audioFile: audioFile);
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
      ref.invalidate(conversationTurnAccessProvider(conversationId));
    } on Object catch (error) {
      final bool limitReached =
          error is ApiException && error.code == 'CONVERSATION_TURNS_FULL';
      final bool locked =
          error is ApiException && error.code == 'CONVERSATION_LOCKED';
      if (limitReached || locked) {
        ref.invalidate(conversationTurnAccessProvider(conversationId));
      }
      state = AsyncData<ConversationState>(
        previous.copyWith(
          isSending: false,
          clearFailedMessage: true,
          failedAudioFile: limitReached || locked ? null : audioFile,
          failureReason: limitReached
              ? ConversationSendFailureReason.turnLimitReached
              : locked
              ? ConversationSendFailureReason.conversationLocked
              : ConversationSendFailureReason.audioRequestFailed,
          clearAssistantAudioStatus: true,
        ),
      );
    }
  }

  Future<void> _sendStream(
    ApiConversationRepository repository, {
    String? text,
    ConversationAudioFile? audioFile,
    String? retryTurnId,
  }) async {
    await cancelActiveStream();
    _localPlaybackFailed = false;
    final api = ConversationStreamApi(repository.apiClient);
    final requestId = newConversationRequestId();
    final token = CancelToken();
    _activeStreamToken = token;
    final localUserId = 'local-user-$requestId';
    final localAssistantId = 'local-assistant-$requestId';
    final requestTrace = (audioFile?.latencyTrace ?? LatencyTrace())
        .claimRequest();
    _activeStreamTrace = requestTrace;
    _activeStreamAssistantId = localAssistantId;
    _firstTextFrameSeen = false;
    final initial = state.requireValue;
    state = AsyncData(
      initial.copyWith(
        messages: text == null || retryTurnId != null
            ? initial.messages
            : <ConversationMessage>[
                ...initial.messages,
                ConversationMessage(
                  id: localUserId,
                  conversationId: conversationId,
                  role: ConversationMessageRole.user,
                  content: text,
                  createdAt: DateTime.now(),
                  isLocalPending: true,
                ),
              ],
        isSending: true,
        clearFailedMessage: true,
        clearFailedAudioFile: true,
        clearFailedTurnId: true,
        clearPendingTurnId: true,
        clearPendingRequestId: true,
        clearUnconfirmedText: true,
        clearUnconfirmedAudioFile: true,
        clearRevealingAssistant: true,
        minVisibleAssistantChars: 0,
        failureReason: null,
      ),
    );

    String? turnId;
    String? attemptId;
    var expectedSeq = 0;
    var nextSegment = 0;
    var terminal = false;
    var partial = '';
    var deltaCount = 0;
    var firstAudioSeen = false;
    try {
      final path = retryTurnId != null
          ? 'conversations/turns/$retryTurnId/retry/stream/'
          : 'conversations/$conversationId/turn/stream/';
      final Object? data = retryTurnId != null
          ? null
          : audioFile != null
          ? ConversationStreamApi.audioForm(
              bytes: audioFile.bytes,
              filename: audioFile.filename,
              contentType: audioFile.contentType,
            )
          : <String, String>{'text': text!};
      await for (final event in api.events(
        path: path,
        data: data,
        cancelToken: token,
        idempotencyKey: requestId,
        trace: requestTrace,
      )) {
        if (!ref.mounted || token.isCancelled) break;
        final seq = event['seq'];
        final currentTurn = event['turn_id'];
        final currentAttempt = event['attempt_id'];
        if (seq != expectedSeq ||
            currentTurn is! String ||
            currentAttempt is! String ||
            (turnId != null && currentTurn != turnId) ||
            (attemptId != null && currentAttempt != attemptId)) {
          throw const FormatException('Out-of-order conversation event.');
        }
        expectedSeq++;
        turnId = currentTurn;
        attemptId = currentAttempt;
        final current = state.requireValue;
        switch (event['event']) {
          case 'turn_started':
            if (seq != 0) throw const FormatException('Duplicate turn start.');
            break;
          case 'user_message_committed':
            final userId = event['user_message_id'];
            final committedText = event['text'];
            if (userId is! String || committedText is! String) {
              throw const FormatException('Invalid committed user message.');
            }
            final replacement = ConversationMessage(
              id: userId,
              conversationId: conversationId,
              role: ConversationMessageRole.user,
              content: committedText,
              createdAt: DateTime.now(),
            );
            final existing = current.messages.any(
              (message) => message.id == userId,
            );
            state = AsyncData(
              current.copyWith(
                messages: existing
                    ? current.messages
                          .where((message) => message.id != localUserId)
                          .toList()
                    : <ConversationMessage>[
                        ...current.messages.where(
                          (message) => message.id != localUserId,
                        ),
                        replacement,
                      ],
              ),
            );
            break;
          case 'text_delta':
            final delta = event['delta'];
            if (delta is! String) {
              throw const FormatException('Invalid text delta.');
            }
            partial += delta;
            _bufferedAssistantText = partial;
            if (deltaCount == 0) requestTrace.mark('first_text_delta');
            if (deltaCount < 32) {
              requestTrace.mark(
                'text_delta',
                fields: <String, Object?>{
                  'delta_index': deltaCount,
                  'delta_chars': delta.length,
                },
              );
            }
            deltaCount++;
            if (_localPlaybackFailed) _showAssistantPrefix(partial.length);
            break;
          case 'audio_segment':
            final index = event['segment_index'];
            if (index != nextSegment) {
              throw const FormatException('Out-of-order audio segment.');
            }
            nextSegment++;
            if (!firstAudioSeen) {
              firstAudioSeen = true;
              requestTrace.mark('first_audio_segment');
            }
            if (!_localPlaybackFailed) {
              final sentence = event['text'];
              if (sentence is! String) {
                throw const FormatException('Invalid audio segment text.');
              }
              final textEnd = streamSentenceEnd(
                partial,
                sentence,
                _lastAudioTextEnd,
              );
              if (textEnd == null) {
                _failStreamAudio();
              } else {
                _lastAudioTextEnd = textEnd;
                _audioQueue.add((
                  audio: requestTrace.duringDecode(
                    () => VoiceAudioResponse.fromJson(event),
                  ),
                  textEnd: textEnd,
                ));
                unawaited(_playAudioQueue());
              }
            }
            break;
          case 'audio_error':
            _failStreamAudio();
            break;
          case 'turn_completed':
            final assistantId = event['assistant_message_id'];
            final completedText = event['text'];
            if (assistantId is! String || completedText is! String) {
              throw const FormatException('Invalid completed turn.');
            }
            terminal = true;
            _completedAssistantText = completedText;
            _bufferedAssistantText = completedText;
            _completedAssistantId = assistantId;
            _activeStreamAssistantId = assistantId;
            requestTrace.mark(
              'turn_completed',
              fields: <String, Object?>{'delta_count': deltaCount},
            );
            final audioFailed =
                event['audio_status'] == 'failed' ||
                _localPlaybackFailed ||
                (nextSegment == 0 && completedText.isNotEmpty);
            if (audioFailed) _failStreamAudio();
            final visibleText = audioFailed
                ? completedText
                : completedText.substring(
                    0,
                    _releasedAssistantChars.clamp(0, completedText.length),
                  );
            state = AsyncData(
              current.copyWith(
                messages: <ConversationMessage>[
                  ...current.messages.where(
                    (message) => message.id != localAssistantId,
                  ),
                  if (visibleText.isNotEmpty)
                    ConversationMessage(
                      id: assistantId,
                      conversationId: conversationId,
                      role: ConversationMessageRole.assistant,
                      content: visibleText,
                      createdAt: DateTime.now(),
                      audioAvailable: true,
                    ),
                ],
                isSending: false,
                revealingAssistantId: visibleText.isNotEmpty
                    ? assistantId
                    : null,
                clearRevealingAssistant: visibleText.isEmpty,
                clearFailedTurnId: true,
                clearPendingTurnId: true,
                audioRetryMessageId: audioFailed ? assistantId : null,
                clearAudioRetryMessageId: !audioFailed,
                assistantAudioStatus: audioFailed
                    ? AssistantAudioStatus.unavailable
                    : null,
                clearAssistantAudioStatus: !audioFailed,
                failureReason: null,
              ),
            );
            if (!audioFailed && !_playingAudio && _audioQueue.isEmpty) {
              _finishAssistantReveal();
            }
            ref.invalidate(conversationTurnAccessProvider(conversationId));
            break;
          case 'turn_error':
            terminal = true;
            _audioGeneration++;
            _audioQueue.clear();
            if (_assistantFrameWaiter?.isCompleted == false) {
              _assistantFrameWaiter!.complete();
            }
            unawaited(ref.read(conversationAudioPlayerProvider).stop());
            state = AsyncData(
              current.copyWith(
                messages: current.messages
                    .where((message) => message.id != localAssistantId)
                    .toList(),
                isSending: false,
                clearRevealingAssistant: true,
                failedTurnId: turnId,
                failureReason: ConversationSendFailureReason.textRequestFailed,
              ),
            );
            break;
        }
      }
      if (!terminal && ref.mounted && !token.isCancelled) {
        throw const FormatException(
          'Conversation stream ended without a terminal event.',
        );
      }
    } on Object catch (sendError) {
      if (!ref.mounted || token.isCancelled) return;
      if (sendError is ApiException &&
          sendError.statusCode == 409 &&
          (sendError.code == 'PREVIOUS_TURN_UNRESOLVED' ||
              sendError.code == null) &&
          turnId == null) {
        try {
          final unresolved = await api.unresolved(conversationId);
          StreamTurnStatus? previousTurn;
          for (final candidate in unresolved) {
            if (candidate.status == 'pending' || candidate.status == 'failed') {
              previousTurn = candidate;
              break;
            }
          }
          if (previousTurn != null) {
            await _recoverFromStatus(repository, previousTurn);
            if (ref.mounted && text != null) {
              state = AsyncData(
                state.requireValue.copyWith(unconfirmedText: text),
              );
            }
            return;
          }
        } on Object {
          // 이전 turn 조회가 실패하면 이번 요청 키의 상태 확인으로 돌아가요.
        }
      }
      StreamTurnStatus? status;
      Object? lookupError;
      try {
        status = turnId == null
            ? await api.statusForRequest(requestId)
            : await api.status(turnId);
      } on Object catch (error) {
        lookupError = error;
      }
      if (!ref.mounted) return;
      if (status != null) {
        await _recoverFromStatus(repository, status);
      } else if (lookupError is! ApiException ||
          lookupError.statusCode != 404) {
        final current = state.requireValue;
        state = AsyncData(
          current.copyWith(
            messages: current.messages
                .where((message) => message.id != localAssistantId)
                .toList(),
            isSending: false,
            pendingTurnId: turnId,
            pendingRequestId: turnId == null ? requestId : null,
            unconfirmedText: text,
            unconfirmedAudioFile: audioFile,
            failureReason: null,
          ),
        );
      } else {
        final current = state.requireValue;
        state = AsyncData(
          current.copyWith(
            messages: current.messages
                .where(
                  (message) =>
                      message.id != localUserId &&
                      message.id != localAssistantId,
                )
                .toList(),
            isSending: false,
            failedMessage: text,
            failedAudioFile: audioFile,
            failureReason: audioFile == null
                ? ConversationSendFailureReason.textRequestFailed
                : ConversationSendFailureReason.audioRequestFailed,
          ),
        );
      }
    } finally {
      if (identical(_activeStreamToken, token)) _activeStreamToken = null;
    }
  }

  Future<void> _recoverFromStatus(
    ApiConversationRepository repository,
    StreamTurnStatus status,
  ) async {
    final page = await _loadLatestPage(repository);
    if (!ref.mounted) return;
    state = AsyncData(
      ConversationState(
        messages: page.results,
        oldestOffset: page.pagination.offset,
        failedTurnId: status.status == 'failed' ? status.turnId : null,
        pendingTurnId: status.status == 'pending' ? status.turnId : null,
        audioRetryMessageId:
            status.status == 'completed' && status.audioStatus == 'failed'
            ? status.assistantMessageId
            : null,
        failureReason: status.status == 'failed'
            ? ConversationSendFailureReason.textRequestFailed
            : null,
        assistantAudioStatus:
            status.status == 'completed' && status.audioStatus == 'failed'
            ? AssistantAudioStatus.unavailable
            : null,
      ),
    );
  }

  Future<void> _playAudioQueue() async {
    if (_playingAudio) return;
    _playingAudio = true;
    final generation = _audioGeneration;
    try {
      while (_audioQueue.isNotEmpty && generation == _audioGeneration) {
        final item = _audioQueue.removeFirst();
        if (item.textEnd case final textEnd?) {
          final priorEnd = _releasedAssistantChars;
          _showAssistantPrefix(textEnd, minVisibleChars: priorEnd);
          _assistantFrameThreshold = streamSentenceLeadingSpaceEnd(
            _completedAssistantText ?? _bufferedAssistantText,
            priorEnd,
            textEnd,
          );
          if (_visibleAssistantChars <= _assistantFrameThreshold) {
            final waiter = Completer<void>();
            _assistantFrameWaiter = waiter;
            await waiter.future;
            _assistantFrameWaiter = null;
          }
        }
        if (generation != _audioGeneration || !ref.mounted) break;
        await ref.read(conversationAudioPlayerProvider).play(item.audio);
      }
    } on Object {
      if (generation == _audioGeneration) _failStreamAudio();
    } finally {
      _playingAudio = false;
      if (generation == _audioGeneration && ref.mounted) {
        _finishAssistantReveal();
      }
      if (_audioQueue.isNotEmpty && ref.mounted) {
        unawaited(_playAudioQueue());
      }
    }
  }

  void _showAssistantPrefix(int end, {int? minVisibleChars}) {
    if (!ref.mounted || !state.hasValue) return;
    final text = _completedAssistantText ?? _bufferedAssistantText;
    final safeEnd = end.clamp(0, text.length);
    if (safeEnd <= _releasedAssistantChars && minVisibleChars == null) return;
    _releasedAssistantChars = safeEnd;
    final id = _completedAssistantId ?? _activeStreamAssistantId;
    if (id == null || safeEnd == 0) return;
    final current = state.requireValue;
    final existing = current.messages
        .where((message) => message.id == id)
        .firstOrNull;
    final message =
        existing?.copyWith(content: text.substring(0, safeEnd)) ??
        ConversationMessage(
          id: id,
          conversationId: conversationId,
          role: ConversationMessageRole.assistant,
          content: text.substring(0, safeEnd),
          createdAt: DateTime.now(),
          isLocalPending: _completedAssistantId == null,
          audioAvailable: _completedAssistantId != null,
        );
    state = AsyncData(
      current.copyWith(
        messages: <ConversationMessage>[
          ...current.messages.where((item) => item.id != id),
          message,
        ],
        revealingAssistantId: id,
        minVisibleAssistantChars:
            minVisibleChars ?? current.minVisibleAssistantChars,
      ),
    );
  }

  void _failStreamAudio() {
    _audioGeneration++;
    _audioQueue.clear();
    _localPlaybackFailed = true;
    if (_assistantFrameWaiter?.isCompleted == false) {
      _assistantFrameWaiter!.complete();
    }
    if (!ref.mounted) return;
    unawaited(ref.read(conversationAudioPlayerProvider).stop());
    _showAssistantPrefix(
      (_completedAssistantText ?? _bufferedAssistantText).length,
    );
    if (!ref.mounted || !state.hasValue) return;
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        assistantAudioStatus: AssistantAudioStatus.unavailable,
        audioRetryMessageId: _completedAssistantId,
        clearAudioRetryMessageId: _completedAssistantId == null,
      ),
    );
  }

  void _finishAssistantReveal() {
    final complete = _completedAssistantText;
    if (complete == null || _audioQueue.isNotEmpty || _localPlaybackFailed) {
      return;
    }
    _showAssistantPrefix(complete.length);
    final current = state.value;
    if (current != null && _visibleAssistantChars >= complete.length) {
      state = AsyncData(current.copyWith(clearRevealingAssistant: true));
    }
  }

  Future<void> retryFailedMessage() async {
    final turnId = state.value?.failedTurnId;
    final repository = ref.read(conversationRepositoryProvider);
    if (turnId != null && repository is ApiConversationRepository) {
      await _sendStream(repository, retryTurnId: turnId);
      return;
    }
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

  Future<void> retryAssistantAudio() async {
    final assistantId = state.value?.audioRetryMessageId;
    final repository = ref.read(conversationRepositoryProvider);
    if (assistantId == null ||
        repository is! ApiConversationRepository ||
        state.value?.isSending == true) {
      return;
    }
    await cancelActiveStream();
    _localPlaybackFailed = false;
    final api = ConversationStreamApi(repository.apiClient);
    final token = CancelToken();
    _activeStreamToken = token;
    state = AsyncData(state.requireValue.copyWith(isSending: true));
    var expectedSeq = 0;
    var nextSegment = 0;
    var terminal = false;
    try {
      await for (final event in api.events(
        path: 'conversations/messages/$assistantId/audio/stream/',
        cancelToken: token,
      )) {
        if (!ref.mounted || token.isCancelled) return;
        if (event['seq'] != expectedSeq++) {
          throw const FormatException('Out-of-order audio retry event.');
        }
        switch (event['event']) {
          case 'audio_segment':
            if (event['segment_index'] != nextSegment++) {
              throw const FormatException('Out-of-order audio retry segment.');
            }
            if (!_localPlaybackFailed) {
              _audioQueue.add((
                audio: VoiceAudioResponse.fromJson(event),
                textEnd: null,
              ));
              unawaited(_playAudioQueue());
            }
            break;
          case 'audio_completed':
            terminal = true;
            state = AsyncData(
              state.requireValue.copyWith(
                isSending: false,
                clearAudioRetryMessageId: !_localPlaybackFailed,
                clearAssistantAudioStatus: !_localPlaybackFailed,
              ),
            );
            break;
          case 'audio_error':
            terminal = true;
            _audioGeneration++;
            _audioQueue.clear();
            state = AsyncData(state.requireValue.copyWith(isSending: false));
            break;
        }
      }
      if (!terminal) {
        throw const FormatException(
          'Audio retry ended without terminal event.',
        );
      }
    } on Object {
      if (ref.mounted) {
        state = AsyncData(state.requireValue.copyWith(isSending: false));
      }
    } finally {
      if (identical(_activeStreamToken, token)) _activeStreamToken = null;
    }
  }

  Future<void> playAssistantAudio(String assistantId) async {
    final repository = ref.read(conversationRepositoryProvider);
    if (repository is! ApiConversationRepository ||
        state.value?.isSending == true) {
      throw StateError('Assistant audio is unavailable.');
    }
    if (_activeReplayMessageId == assistantId) return;
    if (_activeReplayMessageId != null) {
      await stopAssistantAudio(_activeReplayMessageId!);
    } else if (_playingAudio || _audioQueue.isNotEmpty) {
      await cancelActiveStream();
    }

    final token = CancelToken();
    _activeStreamToken = token;
    _activeReplayMessageId = assistantId;
    var expectedSeq = 0;
    var nextSegment = 0;
    var started = false;
    var completed = false;
    try {
      await for (final event
          in ConversationStreamApi(repository.apiClient).events(
            path: 'conversations/messages/$assistantId/audio/stream/',
            cancelToken: token,
          )) {
        if (!ref.mounted || token.isCancelled) return;
        if (event['seq'] != expectedSeq++) {
          throw const FormatException('Out-of-order audio replay event.');
        }
        switch (event['event']) {
          case 'audio_started':
            if (started || expectedSeq != 1) {
              throw const FormatException('Duplicate audio replay start.');
            }
            started = true;
            break;
          case 'audio_segment':
            if (!started || event['segment_index'] != nextSegment++) {
              throw const FormatException('Out-of-order audio replay segment.');
            }
            await ref
                .read(conversationAudioPlayerProvider)
                .play(VoiceAudioResponse.fromJson(event));
            break;
          case 'audio_completed':
            if (!started) {
              throw const FormatException('Audio replay ended before start.');
            }
            completed = true;
            break;
          case 'audio_error':
            throw const ConversationAudioException(
              'Assistant audio is unavailable.',
              reason: ConversationAudioExceptionReason.playbackFailed,
            );
          default:
            throw const FormatException('Unknown audio replay event.');
        }
      }
      if (!token.isCancelled && !completed) {
        throw const FormatException('Audio replay ended without completion.');
      }
    } on Object {
      if (token.isCancelled) return;
      token.cancel('Audio replay failed');
      rethrow;
    } finally {
      if (identical(_activeStreamToken, token)) {
        _activeStreamToken = null;
        _activeReplayMessageId = null;
      }
    }
  }

  Future<void> stopAssistantAudio(String assistantId) async {
    if (_activeReplayMessageId != assistantId) return;
    _activeStreamToken?.cancel('Audio replay stopped');
    _activeStreamToken = null;
    _activeReplayMessageId = null;
    await ref.read(conversationAudioPlayerProvider).stop();
  }

  Future<void> refreshTurnStatus() async {
    final current = state.value;
    final repository = ref.read(conversationRepositoryProvider);
    final turnId = current?.pendingTurnId ?? current?.failedTurnId;
    final requestId = current?.pendingRequestId;
    if ((turnId == null && requestId == null) ||
        repository is! ApiConversationRepository) {
      return;
    }
    try {
      final api = ConversationStreamApi(repository.apiClient);
      final status = turnId == null
          ? await api.statusForRequest(requestId!)
          : await api.status(turnId);
      await _recoverFromStatus(repository, status);
    } on Object catch (error) {
      if (error is ApiException && error.statusCode == 404 && ref.mounted) {
        final current = state.requireValue;
        state = AsyncData(
          current.copyWith(
            messages: current.messages
                .where((message) => !message.isLocalPending)
                .toList(),
            clearPendingRequestId: true,
            clearPendingTurnId: true,
            failedMessage: current.unconfirmedText,
            failedAudioFile: current.unconfirmedAudioFile,
            clearUnconfirmedText: true,
            clearUnconfirmedAudioFile: true,
            failureReason: current.unconfirmedAudioFile == null
                ? ConversationSendFailureReason.textRequestFailed
                : ConversationSendFailureReason.audioRequestFailed,
          ),
        );
      }
    }
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
