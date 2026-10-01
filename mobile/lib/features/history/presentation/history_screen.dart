import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    this.onStartTypeSelected,
    this.onConversationSelected,
    super.key,
  });
  final ValueChanged<ConversationStartType>? onStartTypeSelected;
  final ValueChanged<String>? onConversationSelected;
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _deleting = {};

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final conversations = ref.watch(conversationHistoryControllerProvider);
    final controller = ref.read(conversationHistoryControllerProvider.notifier);
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      appBar: AppBar(
        title: Text(copy.conversationsLabel),
        actions: [
          IconButton(
            tooltip: copy.newConversationLabel,
            onPressed: _showStartSheet,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: conversations.when(
        loading: () => AppAsyncStateView.loading(message: copy.loadingHistory),
        error: (_, _) => AppAsyncStateView.error(
          message: copy.historyLoadFailed,
          onRetry: controller.reload,
        ),
        data: (value) => Column(
          children: [
            if (conversations.isLoading) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(conversationHistoryControllerProvider);
                  try {
                    await ref.read(
                      conversationHistoryControllerProvider.future,
                    );
                  } on Object {
                    // 오류는 provider의 재시도 화면에서 표시해요.
                  }
                },
                child: ListView.separated(
                  key: const PageStorageKey('conversation-history-scroll'),
                  controller: MainTabScope.maybeOf(context)?.controllers[1],
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: value.page.items.isEmpty
                      ? 1
                      : value.page.items.length + 1,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: AppSpacing.screenPadding,
                    endIndent: AppSpacing.screenPadding,
                  ),
                  itemBuilder: (context, index) {
                    if (value.page.items.isEmpty) {
                      return AppAsyncStateView.empty(
                        title: copy.noConversationsYetTitle,
                        message: copy.historyEmptyMessage,
                      );
                    }
                    if (index == value.page.items.length) {
                      if (!value.page.hasMore) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            if (value.loadMoreFailed)
                              Text(copy.moreConversationsFailed),
                            if (value.isLoadingMore)
                              const CircularProgressIndicator()
                            else
                              OutlinedButton(
                                onPressed: controller.loadMore,
                                child: Text(
                                  value.loadMoreFailed
                                      ? copy.retryLabel
                                      : copy.loadMoreConversationsLabel,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final item = value.page.items[index];
                    return ListTile(
                      key: ValueKey(item.id),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding,
                        vertical: AppSpacing.xs,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.button,
                      ),
                      subtitle: Text(
                        copy.conversationPreview(
                          messageCount: item.messageCount,
                          isActive: item.isActive,
                        ),
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => widget.onConversationSelected?.call(item.id),
                      trailing: _deleting.contains(item.id)
                          ? const SizedBox.square(
                              dimension: AppSize.icon,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PopupMenuButton<String>(
                              tooltip: copy.conversationOptionsLabel,
                              icon: const Icon(Icons.more_horiz_rounded),
                              onSelected: (_) => _deleteConversation(item),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(copy.deleteConversationTooltip),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStartSheet() async {
    final selected = await showConversationStartSheet(context);
    if (mounted && selected != null) widget.onStartTypeSelected?.call(selected);
  }

  Future<void> _deleteConversation(ConversationSummary item) async {
    if (_deleting.contains(item.id)) return;
    final confirmed = await showConversationDeleteDialog(
      context: context,
      title: item.title,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting.add(item.id));
    try {
      final repository = ref.read(conversationRepositoryProvider);
      if (repository is! ConversationDeletionRepository) {
        throw StateError('Conversation deletion is unavailable.');
      }
      await (repository as ConversationDeletionRepository).deleteConversation(
        item.id,
      );
      if (!mounted) return;
      ref.invalidate(conversationHistoryControllerProvider);
      ref.invalidate(recentConversationsControllerProvider);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppCopy.of(context).deleteConversationFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(item.id));
    }
  }
}
