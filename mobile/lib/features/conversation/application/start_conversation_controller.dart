import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartConversationState {
  const StartConversationState({this.isStarting = false, this.errorMessage});

  final bool isStarting;
  final String? errorMessage;

  StartConversationState copyWith({bool? isStarting, String? errorMessage}) {
    return StartConversationState(
      isStarting: isStarting ?? this.isStarting,
      errorMessage: errorMessage,
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
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final ConversationResponse response = await ref
          .read(conversationRepositoryProvider)
          .startFreeChat(
            firstMessage: firstMessage,
            searchContext: searchContext,
            topic: topic,
            conversationDirection: conversationDirection,
            selectedQuestion: selectedQuestion,
          );
      state = const StartConversationState();
      return response;
    } on Object catch (_) {
      state = const StartConversationState(
        errorMessage: 'Could not start the conversation. Please try again.',
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
  }) async {
    state = const StartConversationState(isStarting: true);
    try {
      final ConversationResponse response = await ref
          .read(conversationRepositoryProvider)
          .startFreeChatWithAudio(
            audioFile: audioFile,
            searchContext: searchContext,
            topic: topic,
            conversationDirection: conversationDirection,
            selectedQuestion: selectedQuestion,
          );
      state = const StartConversationState();
      return response;
    } on Object catch (_) {
      state = const StartConversationState(
        errorMessage: 'Could not start the conversation. Please try again.',
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
      final ConversationResponse response = await ref
          .read(conversationRepositoryProvider)
          .startRoleplay(
            roleCharacter: roleCharacter,
            searchContext: searchContext,
          );
      state = const StartConversationState();
      return response;
    } on Object catch (_) {
      state = const StartConversationState(
        errorMessage: 'Could not start roleplay. Please try again.',
      );
      return null;
    }
  }
}

final startConversationControllerProvider =
    NotifierProvider<StartConversationController, StartConversationState>(
      StartConversationController.new,
    );
