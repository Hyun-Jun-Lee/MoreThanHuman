import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/data/api_home_repository.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentConversationsController
    extends AsyncNotifier<List<ConversationSummary>> {
  @override
  Future<List<ConversationSummary>> build() async {
    final AuthSession? session = ref.watch(authControllerProvider).value;
    if (session == null || !session.isAuthenticated) {
      return const <ConversationSummary>[];
    }
    final HomeRepository repository = ref.watch(homeRepositoryProvider);
    return repository.listRecentConversations();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<ConversationSummary>>();
    state = await AsyncValue.guard(
      ref.read(homeRepositoryProvider).listRecentConversations,
    );
  }
}

final AsyncNotifierProvider<
  RecentConversationsController,
  List<ConversationSummary>
>
recentConversationsControllerProvider =
    AsyncNotifierProvider<
      RecentConversationsController,
      List<ConversationSummary>
    >(RecentConversationsController.new);
