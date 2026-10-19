import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/data/api_home_repository.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/home_repository.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/data/onboarding_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  test(
    'suggested start holds the second sentence until first audio ends',
    () async {
      final stream = _StartStreamAdapter();
      final player = _RecordingAudioPlayer(holdFirst: true);
      final container = _streamContainer(stream, player);
      addTearDown(container.dispose);
      final controller = container.read(
        startConversationControllerProvider.notifier,
      );
      final start = controller.startSuggestedFreeChat('topic-id');
      await stream.requested.future;
      stream.event('turn_started', 0, <String, Object?>{
        'conversation_id': 'suggested-id',
      });
      expect(await start, 'suggested-id');
      stream.event('text_delta', 1, <String, Object?>{'delta': 'Hello. '});
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(startStreamPreviewProvider('suggested-id'))
            ?.assistantText,
        '',
      );
      stream.event('audio_segment', 2, _audioSegment);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(startStreamPreviewProvider('suggested-id'))
            ?.assistantText,
        'Hello.',
      );
      controller.onConversationFrameReady('suggested-id', 1);
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      stream.event('text_delta', 3, <String, Object?>{'delta': 'Again?'});
      stream.event('audio_segment', 4, <String, Object?>{
        ..._audioSegment,
        'segment_index': 1,
        'text': 'Again?',
      });
      stream.event('turn_completed', 5, <String, Object?>{
        'conversation_id': 'suggested-id',
        'assistant_message_id': 'assistant-id',
        'text': 'Hello. Again?',
        'audio_status': 'completed',
      });
      await stream.closeEvents();
      expect(
        container
            .read(startStreamPreviewProvider('suggested-id'))
            ?.assistantText,
        'Hello.',
      );
      player.finishFirst();
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(startStreamPreviewProvider('suggested-id'))
            ?.assistantText,
        'Hello. Again?',
      );
      expect(player.playCount, 1);
      controller.onConversationFrameReady('suggested-id', 'Hello. '.length);
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      controller.onConversationFrameReady('suggested-id', 'Hello. A'.length);
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 2);
    },
  );

  test('suggested question also waits for its visible text frame', () async {
    final stream = _StartStreamAdapter();
    final player = _RecordingAudioPlayer();
    final container = _streamContainer(stream, player);
    addTearDown(container.dispose);
    final controller = container.read(
      startConversationControllerProvider.notifier,
    );
    final start = controller.startSuggestedFreeChat('topic-id');
    await stream.requested.future;
    stream.event('turn_started', 0, <String, Object?>{
      'conversation_id': 'suggested-id',
    });
    expect(await start, 'suggested-id');
    stream.event('text_delta', 1, <String, Object?>{'delta': 'Question?'});
    stream.event('audio_segment', 2, <String, Object?>{
      ..._audioSegment,
      'text': 'Question?',
    });
    await Future<void>.delayed(Duration.zero);
    expect(player.playCount, 0);
    controller.onConversationFrameReady('suggested-id');
    await Future<void>.delayed(Duration.zero);
    expect(player.playCount, 1);
    stream.event('turn_completed', 3, <String, Object?>{
      'conversation_id': 'suggested-id',
      'assistant_message_id': 'assistant-id',
      'text': 'Question?',
      'audio_status': 'completed',
    });
    await stream.closeEvents();
  });

  test(
    'free chat opens on committed input and waits for the visible frame to play',
    () async {
      final stream = _StartStreamAdapter();
      final player = _RecordingAudioPlayer();
      final container = _streamContainer(stream, player);
      addTearDown(container.dispose);
      final controller = container.read(
        startConversationControllerProvider.notifier,
      );
      final start = controller.startFreeChat(firstMessage: 'Hello');
      await stream.requested.future;
      stream.event('turn_started', 0);
      stream.event('user_message_committed', 1, <String, Object?>{
        'conversation_id': 'conversation-id',
        'user_message_id': 'user-id',
        'text': 'Hello',
      });
      expect((await start)?.conversationId, 'conversation-id');
      stream.event('text_delta', 2, <String, Object?>{'delta': 'Hi there.'});
      stream.event('audio_segment', 3, <String, Object?>{
        ..._audioSegment,
        'text': 'Hi there.',
      });
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 0);
      expect(
        container
            .read(startStreamPreviewProvider('conversation-id'))
            ?.assistantText,
        'Hi there.',
      );
      controller.onConversationFrameReady('conversation-id', 1);
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      expect(
        container
            .read(startStreamPreviewProvider('conversation-id'))
            ?.minVisibleAssistantChars,
        0,
      );
      controller.onConversationFrameReady(
        'conversation-id',
        'Hi there.'.length,
      );
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      stream.event('turn_completed', 4, <String, Object?>{
        'conversation_id': 'conversation-id',
        'assistant_message_id': 'assistant-id',
        'text': 'Hi there.',
        'audio_status': 'completed',
      });
      await stream.closeEvents();
    },
  );

  test(
    'roleplay shows text and plays audio before its turn completes',
    () async {
      final stream = _StartStreamAdapter();
      final player = _RecordingAudioPlayer();
      final container = _streamContainer(stream, player);
      addTearDown(container.dispose);
      final controller = container.read(
        startConversationControllerProvider.notifier,
      );
      final pendingReady = Completer<String>();
      final start = controller.startRoleplay(
        roleCharacter: 'a barista',
        onStreamStarted: pendingReady.complete,
      );
      await stream.requested.future;
      stream.event('turn_started', 0);
      stream.event('text_delta', 1, <String, Object?>{'delta': 'Welcome.'});
      stream.event('audio_segment', 2, <String, Object?>{
        ..._audioSegment,
        'text': 'Welcome.',
      });
      final pendingId = await pendingReady.future;
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(startStreamPreviewProvider(pendingId))?.assistantText,
        'Welcome.',
      );
      expect(player.playCount, 0);
      controller.onConversationFrameReady(pendingId);
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      stream.event('turn_completed', 3, <String, Object?>{
        'conversation_id': 'roleplay-id',
        'assistant_message_id': 'assistant-id',
        'text': 'Welcome.',
        'audio_status': 'completed',
      });
      expect((await start)?.conversationId, 'roleplay-id');
      expect(
        container.read(startStreamPreviewProvider(pendingId))?.conversationId,
        'roleplay-id',
      );
      controller.onConversationFrameReady('roleplay-id');
      await Future<void>.delayed(Duration.zero);
      expect(player.playCount, 1);
      await stream.closeEvents();
    },
  );

  test('roleplay stream error clears its preview before leaving', () async {
    final stream = _StartStreamAdapter();
    final player = _RecordingAudioPlayer();
    final container = _streamContainer(stream, player);
    addTearDown(container.dispose);
    final controller = container.read(
      startConversationControllerProvider.notifier,
    );
    final pendingReady = Completer<String>();
    final start = controller.startRoleplay(
      roleCharacter: 'a barista',
      onStreamStarted: pendingReady.complete,
    );
    await stream.requested.future;
    stream.event('turn_started', 0);
    final pendingId = await pendingReady.future;
    stream.event('text_delta', 1, <String, Object?>{'delta': 'Incomplete'});
    stream.event('turn_error', 2, <String, Object?>{
      'code': 'LLM_FAILED',
      'retryable': true,
    });
    await stream.closeEvents();

    expect(await start, isNull);
    expect(
      container.read(startStreamPreviewProvider(pendingId))?.hasFailed,
      isTrue,
    );
    expect(
      container.read(startStreamPreviewProvider(pendingId))?.assistantText,
      '',
    );
    expect(
      container.read(startConversationControllerProvider).isStarting,
      isFalse,
    );
    expect(
      container.read(startConversationControllerProvider).failureReason,
      StartConversationFailureReason.roleplayRequestFailed,
    );
  });

  test(
    'leaving pending roleplay cancels audio and does not reopen it',
    () async {
      final stream = _StartStreamAdapter();
      final player = _RecordingAudioPlayer();
      final container = _streamContainer(stream, player);
      addTearDown(container.dispose);
      final controller = container.read(
        startConversationControllerProvider.notifier,
      );
      final pendingReady = Completer<String>();
      final start = controller.startRoleplay(
        roleCharacter: 'a barista',
        onStreamStarted: pendingReady.complete,
      );
      await stream.requested.future;
      stream.event('turn_started', 0);
      final pendingId = await pendingReady.future;
      stream.event('text_delta', 1, <String, Object?>{'delta': 'Welcome.'});
      stream.event('audio_segment', 2, <String, Object?>{
        ..._audioSegment,
        'text': 'Welcome.',
      });
      await controller.cancelSuggestedStreamFor(pendingId);
      await stream.closeEvents();

      expect(await start, isNull);
      expect(player.playCount, 0);
      expect(
        container.read(startConversationControllerProvider).isStarting,
        isFalse,
      );
    },
  );

  test('suggested start retries with the same request ID', () async {
    final repository = _FakeConversationRepository()..failSuggestedOnce = true;
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      startConversationControllerProvider.notifier,
    );
    expect(await controller.startSuggestedFreeChat('topic-id'), isNull);
    expect(
      await controller.startSuggestedFreeChat('topic-id'),
      'conversation-id',
    );
    expect(repository.suggestedRequestIds, hasLength(2));
    expect(
      repository.suggestedRequestIds[0],
      repository.suggestedRequestIds[1],
    );
    expect(
      repository.suggestedRequestIds.first,
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
  });

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

  test('starts free chat with a custom focus', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final ConversationResponse? response = await container
        .read(startConversationControllerProvider.notifier)
        .startFreeChat(
          firstMessage: 'The bullpen was decisive.',
          searchContext: 'Lotte won 8-3.',
          topic: '롯데 자이언츠 최근 경기',
          selectedQuestion: 'How did the bullpen affect the game?',
          customFocus: 'the bullpen performance',
        );

    expect(response?.conversationId, 'conversation-id');
    expect(repository.lastCustomFocus, 'the bullpen performance');
    expect(repository.lastFreeChatBody, <String, String?>{
      'first_message': 'The bullpen was decisive.',
      'search_context': 'Lotte won 8-3.',
      'topic': '롯데 자이언츠 최근 경기',
      'conversation_direction': null,
      'selected_question': 'How did the bullpen affect the game?',
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
        .startRoleplay(roleCharacter: 'A cafe barista.');

    expect(repository.lastRoleCharacter, 'A cafe barista.');
    expect(repository.lastRoleplayIncludeAudio, isTrue);
  });

  test('refreshes recent conversations after roleplay starts', () async {
    final _FakeConversationRepository conversationRepository =
        _FakeConversationRepository();
    final _FakeHomeRepository homeRepository = _FakeHomeRepository();
    final ProviderContainer container = _conversationContainer(
      conversationRepository: conversationRepository,
      homeRepository: homeRepository,
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    final List<ConversationSummary> initialConversations = await container.read(
      recentConversationsControllerProvider.future,
    );

    expect(initialConversations.single.id, 'old-conversation-id');
    expect(homeRepository.callCount, 1);

    await container
        .read(startConversationControllerProvider.notifier)
        .startRoleplay(roleCharacter: 'A cafe barista.');

    final List<ConversationSummary> refreshedConversations = await container
        .read(recentConversationsControllerProvider.future);

    expect(refreshedConversations.single.id, 'new-conversation-id');
    expect(homeRepository.callCount, 2);
  });
}

const _audioSegment = <String, Object?>{
  'segment_index': 0,
  'text': 'Hello.',
  'content_type': 'audio/mpeg',
  'format': 'mp3',
  'base64': 'AQID',
};

ProviderContainer _streamContainer(
  _StartStreamAdapter adapter,
  _RecordingAudioPlayer player,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
  dio.httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(
        ApiConversationRepository(ApiClient(dio)),
      ),
      conversationAudioPlayerProvider.overrideWithValue(player),
    ],
  );
}

class _StartStreamAdapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final _events = StreamController<Uint8List>();

  void event(String name, int seq, [Map<String, Object?> fields = const {}]) {
    _events.add(
      Uint8List.fromList(
        utf8.encode(
          '${jsonEncode(<String, Object?>{'event': name, 'seq': seq, 'turn_id': 'turn-id', 'attempt_id': 'attempt-id', ...fields})}\n',
        ),
      ),
    );
  }

  Future<void> closeEvents() => _events.close();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!requested.isCompleted) requested.complete();
    return ResponseBody(
      _events.stream,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/x-ndjson'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingAudioPlayer implements ConversationAudioPlayer {
  _RecordingAudioPlayer({this.holdFirst = false});

  final bool holdFirst;
  final Completer<void> _firstFinished = Completer<void>();
  int playCount = 0;

  void finishFirst() => _firstFinished.complete();

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    playCount++;
    if (holdFirst && playCount == 1) await _firstFinished.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

ProviderContainer _conversationContainer({
  required _FakeConversationRepository conversationRepository,
  required _FakeHomeRepository homeRepository,
}) {
  return ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(conversationRepository),
      homeRepositoryProvider.overrideWithValue(homeRepository),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      supabaseAuthServiceProvider.overrideWithValue(_FakeSupabaseAuthService()),
      googleIdentityServiceProvider.overrideWithValue(
        _FakeGoogleIdentityService(),
      ),
      onboardingStorageProvider.overrideWithValue(_FakeOnboardingStorage()),
      languagePreferencesRepositoryProvider.overrideWithValue(
        _FakeLanguagePreferencesRepository(),
      ),
    ],
  );
}

class _FakeConversationRepository
    implements
        ConversationRepository,
        CustomFocusConversationRepository,
        SuggestedConversationRepository {
  bool failSuggestedOnce = false;
  final List<String> suggestedRequestIds = [];

  @override
  Future<SuggestedConversationResponse> startSuggestedFreeChat({
    required String topicId,
    required String startRequestId,
    bool includeAudioResponse = true,
  }) async {
    suggestedRequestIds.add(startRequestId);
    if (failSuggestedOnce) {
      failSuggestedOnce = false;
      throw StateError('response lost');
    }
    return const SuggestedConversationResponse(
      conversationId: 'conversation-id',
      assistantMessageId: 'assistant-message-id',
      response: 'What do you like?',
    );
  }

  Map<String, String?>? lastFreeChatBody;
  String? lastRoleCharacter;
  String? lastAudioFilename;
  bool? lastFreeChatIncludeAudio;
  bool? lastFreeChatAudioIncludeAudio;
  bool? lastRoleplayIncludeAudio;
  String? lastCustomFocus;

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
  Future<MultimodalConversationResponse> startFreeChatWithCustomFocus({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  }) async {
    lastCustomFocus = customFocus;
    lastFreeChatIncludeAudio = includeAudioResponse;
    lastFreeChatBody = <String, String?>{
      'first_message': firstMessage,
      'search_context': searchContext,
      'topic': topic,
      'conversation_direction': null,
      'selected_question': selectedQuestion,
    };
    return _response(ConversationType.freeChat);
  }

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudioAndCustomFocus({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? selectedQuestion,
    required String customFocus,
    bool includeAudioResponse = true,
  }) async {
    lastAudioFilename = audioFile.filename;
    lastCustomFocus = customFocus;
    lastFreeChatAudioIncludeAudio = includeAudioResponse;
    lastFreeChatBody = <String, String?>{
      'first_message': null,
      'search_context': searchContext,
      'topic': topic,
      'conversation_direction': null,
      'selected_question': selectedQuestion,
    };
    return _response(ConversationType.freeChat);
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

class _FakeHomeRepository implements HomeRepository {
  int callCount = 0;

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 5,
  }) async {
    callCount += 1;
    final String conversationId = callCount == 1
        ? 'old-conversation-id'
        : 'new-conversation-id';
    return <ConversationSummary>[
      ConversationSummary(
        id: conversationId,
        title: 'Roleplay',
        kind: ConversationKind.roleplay,
        messageCount: 1,
        isActive: true,
        updatedAt: DateTime(2026, 8, 14),
      ),
    ];
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> bootstrap(LearningLanguageContext? pendingLanguage) =>
      getCurrentUser();

  @override
  Future<UserProfile> getCurrentUser() async {
    return UserProfile(
      id: 'user-id',
      email: 'learner@example.com',
      name: 'Learner',
      isActive: true,
      createdAt: DateTime(2026, 8, 14),
      updatedAt: DateTime(2026, 8, 14),
    );
  }
}

class _FakeSupabaseAuthService implements SupabaseAuthService {
  @override
  Stream<SupabaseSessionChange> get authStateChanges =>
      const Stream<SupabaseSessionChange>.empty();

  @override
  Future<void> expireSession() async {}

  @override
  Future<bool> hasCurrentSession() async => true;

  @override
  Future<String?> readAccessToken() async => 'access-token';

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async {
    return 'refreshed-token';
  }

  @override
  Future<void> signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
  }) async {}

  @override
  Future<void> signInWithAppleToken({
    required String idToken,
    required String rawNonce,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<GoogleIdentityTokens?> signIn() async {
    return const GoogleIdentityTokens(
      idToken: 'google-id-token',
      accessToken: 'google-access-token',
    );
  }

  @override
  Future<void> signOut() async {}
}

class _FakeOnboardingStorage implements OnboardingStorage {
  @override
  Future<void> clearPendingLanguageContext() async {}

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}

  @override
  Future<LearningLanguageContext?> readPendingLanguageContext() async => null;

  @override
  Future<void> writePendingLanguageContext(
    LearningLanguageContext context,
  ) async {}
}

class _FakeLanguagePreferencesRepository
    implements LanguagePreferencesRepository {
  @override
  Future<LearningLanguageContext> getLanguagePreferences() async {
    return LearningLanguageContext.defaultContext;
  }

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async {
    return context;
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
