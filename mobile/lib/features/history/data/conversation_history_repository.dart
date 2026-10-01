import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationPage {
  const ConversationPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
  });
  final List<ConversationSummary> items;
  final int nextOffset;
  final bool hasMore;
}

abstract interface class ConversationHistoryRepository {
  Future<ConversationPage> list({int offset = 0, int limit = 20});
}

class ApiConversationHistoryRepository
    implements ConversationHistoryRepository {
  const ApiConversationHistoryRepository(this.client);
  final ApiClient client;

  @override
  Future<ConversationPage> list({int offset = 0, int limit = 20}) async {
    final response = await client.get<ConversationPage>(
      'conversations/',
      queryParameters: {'limit': limit, 'offset': offset},
      decodeData: (json) {
        if (json is! Map<String, dynamic> ||
            json['results'] is! List ||
            json['pagination'] is! Map<String, dynamic>) {
          throw const FormatException('Conversation page payload is invalid.');
        }
        final items = (json['results'] as List)
            .map(ConversationSummary.fromJson)
            .toList();
        final pagination = json['pagination'] as Map<String, dynamic>;
        if (pagination['has_more'] is! bool) {
          throw const FormatException('Conversation pagination is invalid.');
        }
        return ConversationPage(
          items: items,
          nextOffset: offset + items.length,
          hasMore: pagination['has_more'] == true && items.isNotEmpty,
        );
      },
    );
    return response.data;
  }
}

final conversationHistoryRepositoryProvider =
    Provider<ConversationHistoryRepository>(
      (ref) => ApiConversationHistoryRepository(ref.watch(apiClientProvider)),
    );
