import 'dart:async';

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

  test('starts roleplay with role character', () async {
    final _FakeConversationRepository repository =
        _FakeConversationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(startConversationControllerProvider.notifier)
        .startRoleplay(
          roleCharacter: 'A cafe barista.',
          roleplayDifficulty: 'CHALLENGE',
        );

    expect(repository.lastRoleCharacter, 'A cafe barista.');
    expect(repository.lastRoleplayDifficulty, 'CHALLENGE');
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

class _FakeConversationRepository implements ConversationRepository {
  Map<String, String?>? lastFreeChatBody;
  String? lastRoleCharacter;
  String? lastRoleplayDifficulty;
  String? lastAudioFilename;
  bool? lastFreeChatIncludeAudio;
  bool? lastFreeChatAudioIncludeAudio;
  bool? lastRoleplayIncludeAudio;

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
  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String roleplayDifficulty = 'NORMAL',
    String? searchContext,
    bool includeAudioResponse = true,
  }) async {
    lastRoleCharacter = roleCharacter;
    lastRoleplayDifficulty = roleplayDifficulty;
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
