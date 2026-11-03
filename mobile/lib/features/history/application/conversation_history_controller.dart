import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/history/data/conversation_history_repository.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationHistoryState {
  const ConversationHistoryState({
    required this.page,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });
  final ConversationPage page;
  final bool isLoadingMore;
  final bool loadMoreFailed;
}

class ConversationHistoryController
    extends AsyncNotifier<ConversationHistoryState> {
  int _generation = 0;
  String? _userId;
  int _loadedOffset = 20;

  @override
  Future<ConversationHistoryState> build() async {
    final generation = ++_generation;
    final userId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.user?.id),
    );
    if (userId != _userId) {
      _userId = userId;
      _loadedOffset = 20;
    }
    if (userId == null) {
      return const ConversationHistoryState(
        page: ConversationPage(items: [], nextOffset: 0, hasMore: false),
      );
    }
    final repository = ref.watch(conversationHistoryRepositoryProvider);
    // 대화에서 돌아오면 읽던 범위까지 새 offset 기준으로 다시 조회해요.
    var page = await repository.list();
    final items = <String, ConversationSummary>{
      for (final item in page.items) item.id: item,
    };
    while (ref.mounted &&
        generation == _generation &&
        page.hasMore &&
        page.nextOffset < _loadedOffset) {
      final next = await repository.list(offset: page.nextOffset);
      for (final item in next.items) {
        items[item.id] = item;
      }
      if (next.nextOffset <= page.nextOffset) break;
      page = next;
    }
    return ConversationHistoryState(
      page: ConversationPage(
        items: items.values.toList(),
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
      ),
    );
  }

  void reload() => ref.invalidateSelf();

  Future<void> loadMore() async {
    final current = state.value;
    if (state.isLoading ||
        current == null ||
        current.isLoadingMore ||
        !current.page.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      ConversationHistoryState(page: current.page, isLoadingMore: true),
    );
    try {
      final next = await ref
          .read(conversationHistoryRepositoryProvider)
          .list(offset: current.page.nextOffset);
      if (!ref.mounted || generation != _generation) return;
      _loadedOffset = next.nextOffset;
      final items = <String, ConversationSummary>{
        for (final item in current.page.items) item.id: item,
      };
      for (final item in next.items) {
        items[item.id] = item;
      }
      state = AsyncData(
        ConversationHistoryState(
          page: ConversationPage(
            items: items.values.toList(),
            nextOffset: next.nextOffset,
            hasMore: next.hasMore && next.nextOffset > current.page.nextOffset,
          ),
        ),
      );
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ConversationHistoryState(page: current.page, loadMoreFailed: true),
      );
    }
  }
}

final conversationHistoryControllerProvider =
    AsyncNotifierProvider<
      ConversationHistoryController,
      ConversationHistoryState
    >(ConversationHistoryController.new);
