import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:curitalk/features/home/presentation/account_sheet.dart';
import 'package:curitalk/features/home/presentation/conversation_start_sheet.dart';
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
    super.key,
  });

  final ValueChanged<String>? onConversationSelected;
  final ValueChanged<ConversationStartType>? onStartTypeSelected;
  final VoidCallback? onHistorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCopy copy = AppCopy.of(context);
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> recent = ref.watch(
      recentConversationsControllerProvider,
    );
    final bool isRecentRefreshing = ref.watch(
      recentConversationsRefreshingProvider,
    );
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      floatingActionButton: FloatingActionButton(
        tooltip: copy.startConversationTooltip,
        onPressed: () => _showStartSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: MainNavigationBar(
        destination: MainNavigationDestination.home,
        onDestinationSelected: (MainNavigationDestination destination) =>
            _handleDestinationSelected(context, ref, destination, user),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _HomeHeader(
              user: user,
              onProfileTap: () =>
                  showAccountSheet(context: context, ref: ref, user: user),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xl,
              AppSpacing.screenPadding,
              AppSpacing.sectionGap +
                  AppSize.bottomNavigationHeight +
                  AppSize.iconButton,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
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
                        onStart: () => _showStartSheet(context),
                      );
                    }
                    return _RecentConversations(
                      conversations: conversations,
                      isRefreshing: isRefreshing,
                      onSelected: onConversationSelected,
                      onDelete: (ConversationSummary conversation) =>
                          _deleteConversation(context, ref, conversation),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStartSheet(BuildContext context) async {
    final ConversationStartType? selected = await showConversationStartSheet(
      context,
    );
    if (selected != null) {
      onStartTypeSelected?.call(selected);
    }
  }

  void _handleDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    MainNavigationDestination destination,
    UserProfile? user,
  ) {
    switch (destination) {
      case MainNavigationDestination.home:
        return;
      case MainNavigationDestination.chat:
        _showStartSheet(context);
      case MainNavigationDestination.history:
        onHistorySelected?.call();
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
      await ref.read(recentConversationsControllerProvider.notifier).reload();
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

class _RecentConversations extends StatefulWidget {
  const _RecentConversations({
    required this.conversations,
    required this.isRefreshing,
    required this.onSelected,
    required this.onDelete,
  });

  static const List<Color> _colors = <Color>[
    AppPalette.blockLimeSoft,
    AppPalette.blockBlue,
    AppPalette.blockCream,
    AppPalette.blockLilac,
    AppPalette.blockPink,
  ];

  final List<ConversationSummary> conversations;
  final bool isRefreshing;
  final ValueChanged<String>? onSelected;
  final ValueChanged<ConversationSummary> onDelete;

  @override
  State<_RecentConversations> createState() => _RecentConversationsState();
}

class _RecentConversationsState extends State<_RecentConversations> {
  static const int _collapsedCount = 4;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final bool canToggle = widget.conversations.length > _collapsedCount;
    final List<ConversationSummary> visibleConversations =
        canToggle && !_isExpanded
        ? widget.conversations.take(_collapsedCount).toList(growable: false)
        : widget.conversations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            AppSectionLabel(copy.recentLabel),
            if (widget.isRefreshing) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label: copy.updatingConversationsSemanticLabel,
                liveRegion: true,
                child: const SizedBox.square(
                  key: ValueKey<String>(
                    'recent-conversations-refresh-indicator',
                  ),
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: AppBorderWidth.hairline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (
          int index = 0;
          index < visibleConversations.length;
          index++
        ) ...<Widget>[
          RecentConversationCard(
            category: copy.conversationCategory(
              visibleConversations[index].kind.name,
            ),
            title: visibleConversations[index].title,
            preview: copy.conversationPreview(
              messageCount: visibleConversations[index].messageCount,
              isActive: visibleConversations[index].isActive,
            ),
            color: _RecentConversations
                ._colors[index % _RecentConversations._colors.length],
            onTap: widget.onSelected == null
                ? null
                : () => widget.onSelected!(visibleConversations[index].id),
            onDelete: () => widget.onDelete(visibleConversations[index]),
          ),
          if (index != visibleConversations.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
        if (canToggle) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              icon: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(_isExpanded ? copy.showLessLabel : copy.showAllLabel),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.nativeLanguage, required this.onStart});

  final LearningLanguageCode nativeLanguage;
  final VoidCallback onStart;

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
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: copy.startConversationLabel,
          leading: const Icon(Icons.add_rounded),
          onPressed: onStart,
        ),
      ],
    );
  }
}
