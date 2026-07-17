import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiConversationRepository implements ConversationRepository {
  const ApiConversationRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<ConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
  }) async {
    final ApiResponse<ConversationResponse> response = await apiClient
        .post<ConversationResponse>(
          'conversations/start/free-chat/',
          data: <String, Object?>{
            'first_message': firstMessage,
            'search_context': searchContext,
            'topic': topic,
            'conversation_direction': conversationDirection,
            'selected_question': selectedQuestion,
          },
          decodeData: ConversationResponse.fromJson,
        );
    return response.data;
  }

  @override
  Future<ConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
  }) async {
    final ApiResponse<ConversationResponse> response = await apiClient
        .post<ConversationResponse>(
          'conversations/start/roleplay/',
          data: <String, Object?>{
            'role_character': roleCharacter,
            'search_context': searchContext,
          },
          decodeData: ConversationResponse.fromJson,
        );
    return response.data;
  }

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final ApiResponse<PaginatedMessages> response = await apiClient
        .get<PaginatedMessages>(
          'conversations/$conversationId/messages/',
          queryParameters: <String, Object?>{'limit': limit, 'offset': offset},
          decodeData: PaginatedMessages.fromJson,
        );
    return response.data;
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final ApiResponse<MessageResponse> response = await apiClient
        .post<MessageResponse>(
          'conversations/$conversationId/message/',
          data: <String, String>{'message': message},
          decodeData: MessageResponse.fromJson,
        );
    return response.data;
  }

  @override
  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = false,
  }) async {
    final ApiResponse<MultimodalMessageResponse> response = await apiClient
        .post<MultimodalMessageResponse>(
          'conversations/$conversationId/turn/',
          data: <String, Object?>{
            'text': text,
            'include_audio_response': includeAudioResponse,
          },
          decodeData: MultimodalMessageResponse.fromJson,
        );
    return response.data;
  }

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = false,
  }) async {
    final FormData formData = FormData.fromMap(<String, Object?>{
      'audio_file': MultipartFile.fromBytes(
        audioFile.bytes,
        filename: audioFile.filename,
        contentType: DioMediaType.parse(audioFile.contentType),
      ),
      'include_audio_response': includeAudioResponse.toString(),
    });
    final ApiResponse<MultimodalMessageResponse> response = await apiClient
        .post<MultimodalMessageResponse>(
          'conversations/$conversationId/turn/',
          data: formData,
          contentType: Headers.multipartFormDataContentType,
          decodeData: MultimodalMessageResponse.fromJson,
        );
    return response.data;
  }
}

final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((Ref ref) {
      return ApiConversationRepository(ref.watch(apiClientProvider));
    });
