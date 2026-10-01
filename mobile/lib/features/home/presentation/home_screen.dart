import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/home/presentation/conversation_start_sheet.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_home_section.dart';
import 'package:curitalk/features/home/presentation/widgets/recent_conversation_card.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    this.onConversationSelected,
    this.onStartTypeSelected,
    this.onHistorySelected,
    this.onProfileSelected,
    super.key,
  });

  final ValueChanged<String>? onConversationSelected;
  final ValueChanged<ConversationStartType>? onStartTypeSelected;
  final VoidCallback? onHistorySelected;
  final VoidCallback? onProfileSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCopy copy = AppCopy.of(context);
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> recent = ref.watch(
      recentConversationsControllerProvider,
    );
    final bool isAdditionalConversationLocked =
        ref.watch(conversationAccessProvider).value?.isLocked == true;
    final bool isRecentRefreshing = ref.watch(
      recentConversationsRefreshingProvider,
    );
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      body: CustomScrollView(
        key: const PageStorageKey('home-scroll'),
        controller: MainTabScope.maybeOf(context)?.controllers[0],
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _HomeHeader(
              user: user,
              onProfileTap: () => onProfileSelected?.call(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xl,
              AppSpacing.screenPadding,
              AppSpacing.sectionGap,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                const LanguageSnackHomeSection(),
                Row(
                  children: [
                    Expanded(child: AppSectionLabel(copy.recentLabel)),
                    TextButton(
                      onPressed: onHistorySelected,
                      child: Text(copy.viewAllConversationsLabel),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                recent.when(
                  loading: () => AppAsyncStateView.loading(
                    message: copy.loadingRecentConversations,
                  ),
                  error: (_, _) => AppAsyncStateView.error(
                    message: copy.recentConversationsLoadFailed,
                    onRetry: () => ref
                        .read(recentConversationsControllerProvider.notifier)
                        .reload(),
                  ),
                  data: (List<ConversationSummary> conversations) {
                    final bool isRefreshing =
                        recent.isRefreshing ||
                        recent.isReloading ||
                        isRecentRefreshing;
                    if (conversations.isEmpty) {
                      if (isRefreshing) {
                        return AppAsyncStateView.loading(
                          message: copy.updatingConversations,
                        );
                      }
                      return _EmptyHome(
                        nativeLanguage:
                            user?.language.nativeLanguage ??
                            LearningLanguageContext
                                .defaultContext
                                .nativeLanguage,
                      );
                    }
                    return _RecentConversations(
                      conversations: conversations.take(2).toList(),
                      isRefreshing: isRefreshing,
                      onSelected: onConversationSelected,
                      onDelete: (ConversationSummary conversation) =>
                          _deleteConversation(context, ref, conversation),
                    );
                  },
                ),
                if (isAdditionalConversationLocked) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppColorBlockCard(
                    key: const ValueKey('locked-additional-conversation-home'),
                    color: AppPalette.blockCream,
                    semanticLabel: copy.additionalConversationLockedSemantic,
                    onTap: () => showConversationAccessDialog(context),
                    padding: EdgeInsets.zero,
                    child: const SizedBox(
                      width: double.infinity,
                      height: 112,
                      child: Center(
                        child: LockedConversationBadge(
                          dimension: 48,
                          iconSize: 28,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: copy.newConversationLabel,
                  leading: const Icon(Icons.add_rounded),
                  onPressed: () => _showStartSheet(context, ref),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStartSheet(BuildContext context, WidgetRef ref) async {
    if (ref.read(conversationAccessProvider).value?.isLocked == true) {
      await showConversationAccessDialog(context);
      return;
    }
    final ConversationStartType? selected = await showConversationStartSheet(
      context,
    );
    if (selected != null && context.mounted) {
      onStartTypeSelected?.call(selected);
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
      await ref
          .read(recentConversationsControllerProvider.notifier)
          .refreshAfterMutation(
            () => (repository as ConversationDeletionRepository)
                .deleteConversation(conversation.id),
          );
      ref.invalidate(conversationHistoryControllerProvider);
      ref.invalidate(conversationAccessProvider);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppCopy.of(context).deleteConversationFailed)),
        );
      }
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user, required this.onProfileTap});

  final UserProfile? user;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final String name = user?.name.trim() ?? '';
    final String initial = name.isEmpty
        ? '?'
        : name.characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'CURITALK',
              style: AppTypography.headlineMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          _LanguagePairBadge(language: user?.language),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: AppCopy.of(context).profileSemanticLabel(
              user?.name ?? AppCopy.of(context).profileLabel,
            ),
            child: InkWell(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.full),
              ),
              onTap: onProfileTap,
              child: CircleAvatar(
                radius: AppSize.iconButton / 2,
                backgroundColor: AppPalette.blockPink,
                child: Text(initial, style: AppTypography.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePairBadge extends StatelessWidget {
  const _LanguagePairBadge({required this.language});

  final LearningLanguageContext? language;

  @override
  Widget build(BuildContext context) {
    final LearningLanguageContext contextLanguage =
        language ?? LearningLanguageContext.defaultContext;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.full)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          contextLanguage.shortPairLabel(),
          style: AppTypography.captionMono.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _RecentConversations extends StatelessWidget {
  const _RecentConversations({
    required this.conversations,
    required this.isRefreshing,
    required this.onSelected,
    required this.onDelete,
  });
  final List<ConversationSummary> conversations;
  final bool isRefreshing;
  final ValueChanged<String>? onSelected;
  final ValueChanged<ConversationSummary> onDelete;
  static const _colors = [AppPalette.blockLimeSoft, AppPalette.blockBlue];
  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRefreshing)
          const LinearProgressIndicator(
            key: ValueKey('recent-conversations-refresh-indicator'),
          ),
        for (int index = 0; index < conversations.length; index++) ...[
          RecentConversationCard(
            category: copy.conversationCategory(conversations[index].kind.name),
            title: conversations[index].title,
            preview: copy.conversationPreview(
              messageCount: conversations[index].messageCount,
              isActive: conversations[index].isActive,
            ),
            color: _colors[index % _colors.length],
            onTap: onSelected == null
                ? null
                : () => onSelected!(conversations[index].id),
            onDelete: () => onDelete(conversations[index]),
          ),
          if (index != conversations.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.nativeLanguage});

  final LearningLanguageCode nativeLanguage;

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final List<String> starterTopics = TopicStarterExamples.forNativeLanguage(
      nativeLanguage,
    );
    return Column(
      children: <Widget>[
        Text(
          copy.homeEmptyTitle,
          textAlign: TextAlign.center,
          style: AppTypography.headlineLg,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppColorBlockCard(
          color: AppPalette.blockLime,
          child: Column(
            children: <Widget>[
              AppSectionLabel(copy.suggestedStartingPoints),
              SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final String topic in starterTopics.take(3))
                    Chip(label: Text(topic)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
