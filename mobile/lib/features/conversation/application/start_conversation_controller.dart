import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

enum StartConversationFailureReason {
  freeChatRequestFailed,
  roleplayRequestFailed,
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
  @override
  StartConversationState build() {
    return const StartConversationState();
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
    } on Object catch (_) {
      state = const StartConversationState(
        failureReason: StartConversationFailureReason.freeChatRequestFailed,
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
    } on Object catch (_) {
      state = const StartConversationState(
        failureReason: StartConversationFailureReason.freeChatRequestFailed,
      );
      return null;
    }
  }

  Future<ConversationResponse?> startRoleplay({
    required String roleCharacter,
    String roleplayDifficulty = 'NORMAL',
    String? searchContext,
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final ConversationResponse response = await ref
          .read(conversationRepositoryProvider)
          .startRoleplay(
            roleCharacter: roleCharacter,
            roleplayDifficulty: roleplayDifficulty,
            searchContext: searchContext,
            includeAudioResponse: true,
          );
      _storeInitialAssistantAudio(response);
      _refreshRecentConversations();
      state = const StartConversationState();
      return response;
    } on Object catch (_) {
      state = const StartConversationState(
        failureReason: StartConversationFailureReason.roleplayRequestFailed,
      );
      return null;
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
