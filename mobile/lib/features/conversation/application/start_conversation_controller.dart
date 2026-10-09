import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:curitalk/features/conversation/application/conversation_audio_services.dart';
import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/data/conversation_stream_api.dart';
import 'package:curitalk/features/conversation/data/suggested_conversation_stream.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/core/network/api_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

class InitialAssistantAudio {
  const InitialAssistantAudio({
    required this.responseText,
    this.audio,
    this.audioError,
  });

  final String responseText;
  final VoiceAudioResponse? audio;
  final VoiceAudioError? audioError;
}

class InitialAssistantAudioController extends Notifier<InitialAssistantAudio?> {
  InitialAssistantAudioController(this.conversationId);

  final String conversationId;

  @override
  InitialAssistantAudio? build() => null;

  void setAudio(InitialAssistantAudio audio) {
    state = audio;
  }

  void clear() {
    state = null;
  }
}

enum StartConversationFailureReason {
  freeChatRequestFailed,
  roleplayRequestFailed,
  slotsFull,
}

class StartConversationState {
  const StartConversationState({this.isStarting = false, this.failureReason});

  final bool isStarting;
  final StartConversationFailureReason? failureReason;

  StartConversationState copyWith({
    bool? isStarting,
    StartConversationFailureReason? failureReason,
  }) {
    return StartConversationState(
      isStarting: isStarting ?? this.isStarting,
      failureReason: failureReason,
    );
  }
}

class StartConversationController extends Notifier<StartConversationState> {
  String? _pendingSuggestedTopic;
  String? _pendingSuggestedRequestId;
  bool _suggestedRequestSent = false;
  String? _activeSuggestedConversationId;
  String? _activeTurnId;
  String? _activeAttemptId;
  bool _suggestedTerminalSeen = false;
  Completer<String?>? _suggestedStartCompleter;
  int _expectedSeq = 0;
  int _nextSegmentIndex = 0;
  CancelToken? _suggestedCancelToken;
  LatencyTrace? _suggestedTrace;
  StreamSubscription<Map<String, dynamic>>? _suggestedSubscription;
  final Queue<VoiceAudioResponse> _suggestedAudioQueue =
      Queue<VoiceAudioResponse>();
  bool _playingSuggestedAudio = false;
  int _playGeneration = 0;
  String? _failedGeneratedStartTurnId;
  String? _failedGeneratedStartFingerprint;
  String? _pendingGeneratedStartRequestId;
  String? _pendingGeneratedStartFingerprint;

  @override
  StartConversationState build() {
    return const StartConversationState();
  }

  Future<String?> startSuggestedFreeChat(String topicId) async {
    if (state.isStarting) return null;
    if (_pendingSuggestedTopic != topicId) {
      _pendingSuggestedTopic = topicId;
      _pendingSuggestedRequestId = _newRequestId();
    }
    state = const StartConversationState(isStarting: true);
    try {
      final repository = ref.read(conversationRepositoryProvider);
      if (repository is! SuggestedConversationRepository) {
        throw StateError('Suggested conversations are unavailable.');
      }
      if (repository is ApiConversationRepository) {
        if (_suggestedRequestSent && _pendingSuggestedRequestId != null) {
          final api = ConversationStreamApi(repository.apiClient);
          try {
            final status = await api.statusForRequest(
              _pendingSuggestedRequestId!,
            );
            if (status.status == 'pending') {
              state = const StartConversationState(
                failureReason:
                    StartConversationFailureReason.freeChatRequestFailed,
              );
              return null;
            }
            if (status.status == 'completed' && status.conversationId != null) {
              _pendingSuggestedTopic = null;
              _pendingSuggestedRequestId = null;
              _suggestedRequestSent = false;
              _refreshRecentConversations();
              state = const StartConversationState();
              if (status.audioStatus == 'failed') {
                ref
                    .read(
                      suggestedAudioFailureProvider(
                        status.conversationId!,
                      ).notifier,
                    )
                    .setFailed();
              }
              return status.conversationId;
            }
            if (status.status == 'failed') {
              return await _startSuggestedStream(
                repository,
                topicId,
                retryTurnId: status.turnId,
              );
            }
          } on ApiException catch (error) {
            if (error.statusCode != 404) rethrow;
          }
        }
        return await _startSuggestedStream(repository, topicId);
      }
      final response = await (repository as SuggestedConversationRepository)
          .startSuggestedFreeChat(
            topicId: topicId,
            startRequestId: _pendingSuggestedRequestId!,
          );
      if (response.audio != null || response.audioError != null) {
        ref
            .read(
              initialAssistantAudioProvider(response.conversationId).notifier,
            )
            .setAudio(
              InitialAssistantAudio(
                responseText: response.response,
                audio: response.audio,
                audioError: response.audioError,
              ),
            );
      }
      _pendingSuggestedTopic = null;
      _pendingSuggestedRequestId = null;
      _suggestedRequestSent = false;
      _refreshRecentConversations();
      state = const StartConversationState();
      return response.conversationId;
    } on Object catch (error) {
      state = StartConversationState(
        failureReason: _isSlotLimit(error)
            ? StartConversationFailureReason.slotsFull
            : StartConversationFailureReason.freeChatRequestFailed,
      );
      return null;
    }
  }

  Future<String?> _startSuggestedStream(
    ApiConversationRepository repository,
    String topicId, {
    String? retryTurnId,
  }) async {
    await cancelSuggestedStream();
    final Completer<String?> started = Completer<String?>();
    _suggestedStartCompleter = started;
    final CancelToken token = CancelToken();
    final trace = LatencyTrace();
    _suggestedCancelToken = token;
    _suggestedTrace = trace;
    _activeTurnId = null;
    _activeAttemptId = null;
    _suggestedTerminalSeen = false;
    _expectedSeq = 0;
    _nextSegmentIndex = 0;
    final stream = retryTurnId == null
        ? SuggestedConversationStream(repository.apiClient).start(
            topicId: topicId,
            requestId: _pendingSuggestedRequestId!,
            cancelToken: token,
            trace: trace,
          )
        : ConversationStreamApi(repository.apiClient).events(
            path: 'conversations/turns/$retryTurnId/retry/stream/',
            cancelToken: token,
            idempotencyKey: newConversationRequestId(),
            trace: trace,
          );
    _suggestedRequestSent = true;
    _suggestedSubscription = stream.listen(
      (event) {
        try {
          _handleSuggestedEvent(event, started);
        } on Object catch (error) {
          token.cancel('Invalid conversation stream: $error');
          _handleSuggestedError(started);
        }
      },
      onError: (Object error, StackTrace stack) =>
          _handleSuggestedError(started),
      onDone: () {
        if (!_suggestedTerminalSeen && !token.isCancelled) {
          _handleSuggestedError(started);
        }
        _suggestedSubscription = null;
        _suggestedCancelToken = null;
        _suggestedStartCompleter = null;
      },
    );
    return started.future;
  }

  void _handleSuggestedEvent(
    Map<String, dynamic> event,
    Completer<String?> started,
  ) {
    final int? seq = event['seq'] as int?;
    final String? turnId = event['turn_id'] as String?;
    final String? attemptId = event['attempt_id'] as String?;
    if (seq != _expectedSeq || turnId == null || attemptId == null) {
      throw const FormatException('Unexpected conversation event order.');
    }
    _expectedSeq++;
    if (_activeTurnId == null) {
      if (event['event'] != 'turn_started') {
        throw const FormatException('Missing turn_started event.');
      }
      _activeTurnId = turnId;
      _activeAttemptId = attemptId;
    } else if (_activeTurnId != turnId || _activeAttemptId != attemptId) {
      throw const FormatException('Event belongs to another attempt.');
    }
    switch (event['event']) {
      case 'turn_started':
        final String? conversationId = event['conversation_id'] as String?;
        if (conversationId == null || started.isCompleted) {
          throw const FormatException('Missing conversation ID.');
        }
        _activeSuggestedConversationId = conversationId;
        _pendingSuggestedTopic = null;
        _pendingSuggestedRequestId = null;
        _suggestedRequestSent = false;
        _refreshRecentConversations();
        state = const StartConversationState();
        started.complete(conversationId);
        break;
      case 'audio_segment':
        final int? index = event['segment_index'] as int?;
        if (index != _nextSegmentIndex) {
          throw const FormatException('Out-of-order audio segment.');
        }
        _nextSegmentIndex++;
        if (index == 0) _suggestedTrace?.mark('first_audio_segment');
        final trace = _suggestedTrace;
        _suggestedAudioQueue.add(
          trace == null
              ? VoiceAudioResponse.fromJson(event)
              : trace.duringDecode(() => VoiceAudioResponse.fromJson(event)),
        );
        unawaited(_playSuggestedAudio());
        break;
      case 'audio_error':
        _suggestedAudioQueue.clear();
        final conversationId = _activeSuggestedConversationId;
        if (conversationId != null) {
          ref
              .read(suggestedAudioFailureProvider(conversationId).notifier)
              .setFailed();
        }
        break;
      case 'turn_completed':
        _suggestedTerminalSeen = true;
        if (event['audio_status'] == 'failed') {
          final conversationId = _activeSuggestedConversationId;
          if (conversationId != null) {
            ref
                .read(suggestedAudioFailureProvider(conversationId).notifier)
                .setFailed();
          }
        }
        break;
    }
  }

  void _handleSuggestedError(Completer<String?> started) {
    _suggestedAudioQueue.clear();
    unawaited(_stopSuggestedAudio());
    if (!started.isCompleted) {
      state = const StartConversationState(
        failureReason: StartConversationFailureReason.freeChatRequestFailed,
      );
      started.complete(null);
    } else {
      final conversationId = _activeSuggestedConversationId;
      if (conversationId != null) {
        ref
            .read(suggestedAudioFailureProvider(conversationId).notifier)
            .setFailed();
      }
    }
  }

  Future<void> _playSuggestedAudio() async {
    if (_playingSuggestedAudio) return;
    _playingSuggestedAudio = true;
    final generation = _playGeneration;
    try {
      while (_suggestedAudioQueue.isNotEmpty && generation == _playGeneration) {
        final audio = _suggestedAudioQueue.removeFirst();
        await ref.read(conversationAudioPlayerProvider).play(audio);
      }
    } on Object {
      _suggestedAudioQueue.clear();
      final conversationId = _activeSuggestedConversationId;
      if (conversationId != null) {
        ref
            .read(suggestedAudioFailureProvider(conversationId).notifier)
            .setFailed();
      }
    } finally {
      _playingSuggestedAudio = false;
      if (_suggestedAudioQueue.isNotEmpty) {
        unawaited(_playSuggestedAudio());
      }
    }
  }

  Future<void> cancelSuggestedStream() async {
    _playGeneration++;
    _suggestedAudioQueue.clear();
    _activeSuggestedConversationId = null;
    final started = _suggestedStartCompleter;
    if (started != null && !started.isCompleted) started.complete(null);
    _suggestedCancelToken?.cancel('Conversation screen closed');
    await _suggestedSubscription?.cancel();
    _suggestedSubscription = null;
    _suggestedCancelToken = null;
    _suggestedTrace = null;
    _suggestedStartCompleter = null;
    await _stopSuggestedAudio();
  }

  Future<void> _stopSuggestedAudio() async {
    try {
      await ref.read(conversationAudioPlayerProvider).stop();
    } on Object {
      // 취소·오류 정리는 재생 장치 오류가 있어도 계속해요.
    }
  }

  Future<void> cancelSuggestedStreamFor(String conversationId) async {
    if (_activeSuggestedConversationId == conversationId) {
      await cancelSuggestedStream();
    }
  }

  String _newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<ConversationResponse?> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    String? customFocus,
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final ConversationRepository repository = ref.read(
        conversationRepositoryProvider,
      );
      if (repository is ApiConversationRepository) {
        return await _startGeneratedStream(
          repository,
          path: 'conversations/start/free-chat/stream/',
          data: <String, Object?>{
            'first_message': firstMessage,
            'search_context': searchContext,
            'topic': topic,
            'conversation_direction': conversationDirection,
            'selected_question': selectedQuestion,
            'custom_focus': customFocus,
          },
          fingerprint:
              'free:$firstMessage:$topic:$selectedQuestion:$customFocus',
          type: ConversationType.freeChat,
        );
      }
      final ConversationResponse response = customFocus == null
          ? await repository.startFreeChat(
              firstMessage: firstMessage,
              searchContext: searchContext,
              topic: topic,
              conversationDirection: conversationDirection,
              selectedQuestion: selectedQuestion,
              includeAudioResponse: true,
            )
          : await _customFocusRepository(
              repository,
            ).startFreeChatWithCustomFocus(
              firstMessage: firstMessage,
              searchContext: searchContext,
              topic: topic,
              selectedQuestion: selectedQuestion,
              customFocus: customFocus,
              includeAudioResponse: true,
            );
      _storeInitialAssistantAudio(response);
      _refreshRecentConversations();
      state = const StartConversationState();
      return response;
    } on Object catch (error) {
      state = StartConversationState(
        failureReason: _isSlotLimit(error)
            ? StartConversationFailureReason.slotsFull
            : StartConversationFailureReason.freeChatRequestFailed,
      );
      return null;
    }
  }

  Future<ConversationResponse?> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    String? customFocus,
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final ConversationRepository repository = ref.read(
        conversationRepositoryProvider,
      );
      if (repository is ApiConversationRepository) {
        return await _startGeneratedStream(
          repository,
          path: 'conversations/start/free-chat/stream/',
          data: FormData.fromMap(<String, Object?>{
            'audio_file': MultipartFile.fromBytes(
              audioFile.bytes,
              filename: audioFile.filename,
              contentType: DioMediaType.parse(audioFile.contentType),
            ),
            'search_context': searchContext,
            'topic': topic,
            'conversation_direction': conversationDirection,
            'selected_question': selectedQuestion,
            'custom_focus': customFocus,
          }),
          fingerprint:
              'free-audio:${audioFile.filename}:$topic:$selectedQuestion:$customFocus',
          type: ConversationType.freeChat,
          trace: audioFile.latencyTrace,
        );
      }
      final ConversationResponse response = customFocus == null
          ? await repository.startFreeChatWithAudio(
              audioFile: audioFile,
              searchContext: searchContext,
              topic: topic,
              conversationDirection: conversationDirection,
              selectedQuestion: selectedQuestion,
              includeAudioResponse: true,
            )
          : await _customFocusRepository(
              repository,
            ).startFreeChatWithAudioAndCustomFocus(
              audioFile: audioFile,
              searchContext: searchContext,
              topic: topic,
              selectedQuestion: selectedQuestion,
              customFocus: customFocus,
              includeAudioResponse: true,
            );
      _storeInitialAssistantAudio(response);
      _refreshRecentConversations();
      state = const StartConversationState();
      return response;
    } on Object catch (error) {
      state = StartConversationState(
        failureReason: _isSlotLimit(error)
            ? StartConversationFailureReason.slotsFull
            : StartConversationFailureReason.freeChatRequestFailed,
      );
      return null;
    }
  }

  Future<ConversationResponse?> startRoleplay({
    required String roleCharacter,
    String? searchContext,
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final repository = ref.read(conversationRepositoryProvider);
      if (repository is ApiConversationRepository) {
        return await _startGeneratedStream(
          repository,
          path: 'conversations/start/roleplay/stream/',
          data: <String, Object?>{
            'role_character': roleCharacter,
            'search_context': searchContext,
          },
          fingerprint: 'roleplay:$roleCharacter:$searchContext',
          type: ConversationType.rolePlaying,
          roleCharacter: roleCharacter,
        );
      }
      final ConversationResponse response = await repository.startRoleplay(
        roleCharacter: roleCharacter,
        searchContext: searchContext,
        includeAudioResponse: true,
      );
      _storeInitialAssistantAudio(response);
      _refreshRecentConversations();
      state = const StartConversationState();
      return response;
    } on Object catch (error) {
      state = StartConversationState(
        failureReason: _isSlotLimit(error)
            ? StartConversationFailureReason.slotsFull
            : StartConversationFailureReason.roleplayRequestFailed,
      );
      return null;
    }
  }

  Future<ConversationResponse?> _startGeneratedStream(
    ApiConversationRepository repository, {
    required String path,
    required Object data,
    required String fingerprint,
    required ConversationType type,
    String? roleCharacter,
    LatencyTrace? trace,
  }) async {
    await cancelSuggestedStream();
    final api = ConversationStreamApi(repository.apiClient);
    if (_pendingGeneratedStartFingerprint == fingerprint &&
        _pendingGeneratedStartRequestId != null) {
      try {
        final status = await api.statusForRequest(
          _pendingGeneratedStartRequestId!,
        );
        if (status.status == 'pending') {
          state = StartConversationState(
            failureReason: type == ConversationType.rolePlaying
                ? StartConversationFailureReason.roleplayRequestFailed
                : StartConversationFailureReason.freeChatRequestFailed,
          );
          return null;
        }
        if (status.status == 'completed' && status.conversationId != null) {
          _pendingGeneratedStartRequestId = null;
          _pendingGeneratedStartFingerprint = null;
          _refreshRecentConversations();
          state = const StartConversationState();
          return ConversationResponse(
            conversationId: status.conversationId!,
            messageId: status.userMessageId ?? status.assistantMessageId ?? '',
            conversationType: type,
            roleCharacter: roleCharacter,
            response: '',
          );
        }
        if (status.status == 'failed') {
          _failedGeneratedStartTurnId = status.turnId;
          _failedGeneratedStartFingerprint = fingerprint;
        }
        _pendingGeneratedStartRequestId = null;
        _pendingGeneratedStartFingerprint = null;
      } on ApiException catch (error) {
        if (error.statusCode != 404) {
          state = StartConversationState(
            failureReason: type == ConversationType.rolePlaying
                ? StartConversationFailureReason.roleplayRequestFailed
                : StartConversationFailureReason.freeChatRequestFailed,
          );
          return null;
        }
        _pendingGeneratedStartRequestId = null;
        _pendingGeneratedStartFingerprint = null;
      }
    }
    final requestId = newConversationRequestId();
    _pendingGeneratedStartRequestId = requestId;
    _pendingGeneratedStartFingerprint = fingerprint;
    final token = CancelToken();
    _suggestedCancelToken = token;
    _suggestedTrace = trace;
    final retryId = _failedGeneratedStartFingerprint == fingerprint
        ? _failedGeneratedStartTurnId
        : null;
    String? conversationId;
    String? userMessageId;
    String? assistantId;
    String? turnId;
    String? attemptId;
    String responseText = '';
    var expectedSeq = 0;
    var nextSegment = 0;
    var terminal = false;
    try {
      await for (final event in api.events(
        path: retryId == null
            ? path
            : 'conversations/turns/$retryId/retry/stream/',
        data: retryId == null ? data : null,
        idempotencyKey: requestId,
        cancelToken: token,
        trace: trace ?? LatencyTrace(),
      )) {
        if (token.isCancelled) break;
        final currentTurn = event['turn_id'];
        final currentAttempt = event['attempt_id'];
        if (event['seq'] != expectedSeq++ ||
            currentTurn is! String ||
            currentAttempt is! String ||
            (turnId != null && turnId != currentTurn) ||
            (attemptId != null && attemptId != currentAttempt)) {
          throw const FormatException('Invalid conversation start event.');
        }
        turnId = currentTurn;
        attemptId = currentAttempt;
        switch (event['event']) {
          case 'turn_started':
            conversationId = event['conversation_id'] as String?;
            _activeSuggestedConversationId = conversationId;
            break;
          case 'user_message_committed':
            conversationId = event['conversation_id'] as String?;
            userMessageId = event['user_message_id'] as String?;
            _activeSuggestedConversationId = conversationId;
            break;
          case 'text_delta':
            responseText += event['delta'] as String;
            break;
          case 'audio_segment':
            if (event['segment_index'] != nextSegment++) {
              throw const FormatException('Invalid start audio segment order.');
            }
            _suggestedAudioQueue.add(VoiceAudioResponse.fromJson(event));
            unawaited(_playSuggestedAudio());
            break;
          case 'audio_error':
            _suggestedAudioQueue.clear();
            break;
          case 'turn_completed':
            terminal = true;
            conversationId = event['conversation_id'] as String?;
            assistantId = event['assistant_message_id'] as String?;
            responseText = event['text'] as String? ?? responseText;
            _activeSuggestedConversationId = conversationId;
            if (event['audio_status'] == 'failed' && conversationId != null) {
              ref
                  .read(suggestedAudioFailureProvider(conversationId).notifier)
                  .setFailed();
            }
            break;
          case 'turn_error':
            terminal = true;
            _suggestedAudioQueue.clear();
            conversationId =
                event['conversation_id'] as String? ?? conversationId;
            userMessageId =
                event['user_message_id'] as String? ?? userMessageId;
            _failedGeneratedStartTurnId = turnId;
            _failedGeneratedStartFingerprint = fingerprint;
            break;
        }
      }
      if (!terminal) {
        throw const FormatException(
          'Start stream ended without terminal event.',
        );
      }
      if (conversationId == null) {
        state = StartConversationState(
          failureReason: type == ConversationType.rolePlaying
              ? StartConversationFailureReason.roleplayRequestFailed
              : StartConversationFailureReason.freeChatRequestFailed,
        );
        return null;
      }
      _failedGeneratedStartTurnId = null;
      _failedGeneratedStartFingerprint = null;
      _pendingGeneratedStartRequestId = null;
      _pendingGeneratedStartFingerprint = null;
      _refreshRecentConversations();
      state = const StartConversationState();
      return ConversationResponse(
        conversationId: conversationId,
        messageId: userMessageId ?? assistantId ?? '',
        conversationType: type,
        roleCharacter: roleCharacter,
        response: responseText,
      );
    } on Object {
      StreamTurnStatus? status;
      try {
        status = turnId == null
            ? await api.statusForRequest(requestId)
            : await api.status(turnId);
      } on ApiException catch (error) {
        // 요청이 서버에 도달하지 않았다면 기존 시작 화면의 재시도를 사용해요.
        if (error.statusCode == 404) {
          _pendingGeneratedStartRequestId = null;
          _pendingGeneratedStartFingerprint = null;
        }
      }
      if (status != null && status.status == 'failed') {
        _pendingGeneratedStartRequestId = null;
        _pendingGeneratedStartFingerprint = null;
        _failedGeneratedStartTurnId = status.turnId;
        _failedGeneratedStartFingerprint = fingerprint;
        if (status.conversationId != null) {
          state = const StartConversationState();
          _refreshRecentConversations();
          return ConversationResponse(
            conversationId: status.conversationId!,
            messageId: status.userMessageId ?? '',
            conversationType: type,
            roleCharacter: roleCharacter,
            response: '',
          );
        }
      }
      state = StartConversationState(
        failureReason: type == ConversationType.rolePlaying
            ? StartConversationFailureReason.roleplayRequestFailed
            : StartConversationFailureReason.freeChatRequestFailed,
      );
      return null;
    } finally {
      if (identical(_suggestedCancelToken, token)) _suggestedCancelToken = null;
    }
  }

  void _storeInitialAssistantAudio(ConversationResponse response) {
    if (response is! MultimodalConversationResponse) {
      return;
    }
    if (response.audio == null && response.audioError == null) {
      return;
    }
    ref
        .read(initialAssistantAudioProvider(response.conversationId).notifier)
        .setAudio(
          InitialAssistantAudio(
            responseText: response.response,
            audio: response.audio,
            audioError: response.audioError,
          ),
        );
  }

  void _refreshRecentConversations() {
    ref
        .read(recentConversationsRefreshingProvider.notifier)
        .setRefreshing(true);
    ref.invalidate(recentConversationsControllerProvider);
    ref.invalidate(conversationAccessProvider);
  }

  bool _isSlotLimit(Object error) {
    if (error is ApiException && error.code == 'CONVERSATION_SLOTS_FULL') {
      ref.invalidate(conversationAccessProvider);
      return true;
    }
    return false;
  }

  CustomFocusConversationRepository _customFocusRepository(
    ConversationRepository repository,
  ) {
    if (repository is CustomFocusConversationRepository) {
      return repository as CustomFocusConversationRepository;
    }
    throw StateError(
      'Custom focus conversations are unavailable for this repository.',
    );
  }
}

final initialAssistantAudioProvider =
    NotifierProvider.family<
      InitialAssistantAudioController,
      InitialAssistantAudio?,
      String
    >(InitialAssistantAudioController.new);

final startConversationControllerProvider =
    NotifierProvider<StartConversationController, StartConversationState>(
      StartConversationController.new,
    );

class SuggestedAudioFailureController extends Notifier<bool> {
  SuggestedAudioFailureController(this.conversationId);

  final String conversationId;

  @override
  bool build() => false;

  void setFailed() => state = true;
}

final suggestedAudioFailureProvider =
    NotifierProvider.family<SuggestedAudioFailureController, bool, String>(
      SuggestedAudioFailureController.new,
    );
