import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiHomeRepository implements HomeRepository {
  const ApiHomeRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 5,
  }) async {
    final ApiResponse<List<ConversationSummary>> response = await apiClient
        .get<List<ConversationSummary>>(
          'conversations/',
          queryParameters: <String, dynamic>{'limit': limit, 'offset': 0},
          decodeData: (Object? json) {
            if (json is! Map<String, dynamic> || json['results'] is! List) {
              throw const FormatException(
                'Conversation page payload is invalid.',
              );
            }
            return (json['results']! as List<Object?>)
                .map(ConversationSummary.fromJson)
                .toList(growable: false);
          },
        );
    return response.data;
  }
}

final Provider<HomeRepository> homeRepositoryProvider =
    Provider<HomeRepository>((Ref ref) {
      return ApiHomeRepository(ref.watch(apiClientProvider));
    });
