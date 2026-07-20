import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiTopicPrepRepository implements TopicPrepRepository {
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
}

final Provider<TopicPrepRepository> topicPrepRepositoryProvider =
    Provider<TopicPrepRepository>((Ref ref) {
      return ApiTopicPrepRepository(ref.watch(apiClientProvider));
    });
