import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiHomeRepository implements HomeRepository {
  const ApiHomeRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 100,
  }) async {
    final conversations = <ConversationSummary>[];
    var offset = 0;
    while (true) {
      final response = await apiClient.get<_ConversationPage>(
        'conversations/',
        diagnosticSource: 'home_recent',
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
        decodeData: (Object? json) {
          if (json is! Map<String, dynamic> ||
              json['results'] is! List ||
              json['pagination'] is! Map<String, dynamic>) {
            throw const FormatException(
              'Conversation page payload is invalid.',
            );
          }
          final pagination = json['pagination'] as Map<String, dynamic>;
          if (pagination['has_more'] is! bool) {
            throw const FormatException('Conversation pagination is invalid.');
          }
          final results = (json['results']! as List<Object?>)
              .map(ConversationSummary.fromJson)
              .toList(growable: false);
          return _ConversationPage(
            results: results,
            hasMore: pagination['has_more'] as bool,
          );
        },
      );
      final page = response.data;
      if (page.hasMore && page.results.isEmpty) {
        throw const FormatException('Conversation pagination did not advance.');
      }
      conversations.addAll(page.results);
      if (!page.hasMore) return conversations;
      offset += page.results.length;
    }
  }
}

class _ConversationPage {
  const _ConversationPage({required this.results, required this.hasMore});

  final List<ConversationSummary> results;
  final bool hasMore;
}

final Provider<HomeRepository> homeRepositoryProvider =
    Provider<HomeRepository>((Ref ref) {
      return ApiHomeRepository(ref.watch(apiClientProvider));
    });
