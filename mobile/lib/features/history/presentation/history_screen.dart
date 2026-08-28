import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({
    this.onHomeSelected,
    this.onStartTypeSelected,
    this.onConversationSelected,
    super.key,
  });

  final VoidCallback? onHomeSelected;
  final ValueChanged<ConversationStartType>? onStartTypeSelected;
  final ValueChanged<String>? onConversationSelected;

  static const List<Color> _colors = <Color>[
    AppPalette.blockLimeSoft,
    AppPalette.blockBlue,
    AppPalette.blockCream,
    AppPalette.blockLilac,
    AppPalette.blockPink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCopy copy = AppCopy.of(context);
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> conversations = ref.watch(
      recentConversationsControllerProvider,
    );

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      appBar: AppBar(title: Text(copy.historyTitle)),
      bottomNavigationBar: MainNavigationBar(
        destination: MainNavigationDestination.history,
        onDestinationSelected: (MainNavigationDestination destination) =>
            _handleDestinationSelected(context, ref, destination, user),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.xl,
          AppSpacing.screenPadding,
          AppSpacing.sectionGap,
        ),
        child: conversations.when(
          loading: () =>
              AppAsyncStateView.loading(message: copy.loadingHistory),
          error: (_, _) => AppAsyncStateView.error(
            message: copy.historyLoadFailed,
            onRetry: () => ref
                .read(recentConversationsControllerProvider.notifier)
                .reload(),
          ),
          data: (List<ConversationSummary> items) {
            if (items.isEmpty) {
              return AppAsyncStateView.empty(
                title: copy.noConversationsYetTitle,
                message: copy.historyEmptyMessage,
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final ConversationSummary conversation = items[index];
                return RecentConversationCard(
                  category: copy.conversationCategory(conversation.kind.name),
                  title: conversation.title,
                  preview: copy.conversationPreview(
                    messageCount: conversation.messageCount,
                    isActive: conversation.isActive,
                  ),
                  color: _colors[index % _colors.length],
                  onTap: onConversationSelected == null
                      ? null
                      : () => onConversationSelected!(conversation.id),
                  onDelete: () =>
                      _deleteConversation(context, ref, conversation),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    MainNavigationDestination destination,
    UserProfile? user,
  ) {
    switch (destination) {
      case MainNavigationDestination.home:
        onHomeSelected?.call();
      case MainNavigationDestination.chat:
        _showStartSheet(context);
      case MainNavigationDestination.history:
        return;
      case MainNavigationDestination.profile:
        showAccountSheet(context: context, ref: ref, user: user);
    }
  }

  Future<void> _deleteConversation(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary conversation,
  ) async {
    final bool confirmed = await showConversationDeleteDialog(
      context: context,
      title: conversation.title,
    );
    if (!confirmed || !context.mounted) return;
    try {
      final ConversationRepository repository = ref.read(
        conversationRepositoryProvider,
      );
      if (repository is! ConversationDeletionRepository) {
        throw StateError(
          'Conversation deletion is unavailable for this repository.',
        );
      }
      await (repository as ConversationDeletionRepository).deleteConversation(
        conversation.id,
      );
      ref.invalidate(recentConversationsControllerProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppCopy.of(context).deleteConversationFailed)),
        );
      }
    }
  }

  Future<void> _showStartSheet(BuildContext context) async {
    final ConversationStartType? selected = await showConversationStartSheet(
      context,
    );
    if (selected != null) {
      onStartTypeSelected?.call(selected);
    }
  }
}
