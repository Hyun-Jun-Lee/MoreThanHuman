import 'package:curitalk/features/home/domain/conversation_summary.dart';

abstract interface class HomeRepository {
  Future<List<ConversationSummary>> listRecentConversations({int limit = 5});
}
