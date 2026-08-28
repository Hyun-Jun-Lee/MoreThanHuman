import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiTopicPrepRepository
    implements TopicPrepRepository, TopicPrepCustomFocusRepository {
  const ApiTopicPrepRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<TopicPrepResult> prepareTopic(String topic) async {
    final ApiResponse<TopicPrepResult> response = await apiClient
        .post<TopicPrepResult>(
          'search/topic-prep/',
          data: <String, String>{'topic': topic},
          decodeData: TopicPrepResult.fromJson,
        );
    return response.data;
  }

  @override
  Future<CustomFocusQuestions> prepareCustomFocusQuestions({
    required String topic,
    required String customFocus,
  }) async {
    final ApiResponse<CustomFocusQuestions> response = await apiClient
        .post<CustomFocusQuestions>(
          'search/topic-prep/custom-questions/',
          data: <String, String>{'topic': topic, 'custom_focus': customFocus},
          decodeData: CustomFocusQuestions.fromJson,
        );
    return response.data;
  }

  @override
  Future<TopicPrepDirections> regenerateDirections({
    required String topic,
    required List<String> previousDirections,
  }) async {
    final ApiResponse<TopicPrepDirections> response = await apiClient
        .post<TopicPrepDirections>(
          'search/topic-prep/directions/',
          data: <String, Object>{
            'topic': topic,
            'previous_directions': previousDirections,
          },
          decodeData: TopicPrepDirections.fromJson,
        );
    return response.data;
  }
}

final Provider<TopicPrepRepository> topicPrepRepositoryProvider =
    Provider<TopicPrepRepository>((Ref ref) {
      return ApiTopicPrepRepository(ref.watch(apiClientProvider));
    });
