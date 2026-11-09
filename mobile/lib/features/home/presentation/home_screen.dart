import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/application/weekly_topics_controller.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/home/presentation/conversation_start_sheet.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_home_section.dart';
import 'package:curitalk/features/home/presentation/widgets/recent_conversation_card.dart';
import 'package:curitalk/features/home/presentation/widgets/weekly_topic_loop.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    this.onConversationSelected,
    this.onStartTypeSelected,
    super.key,
  });

  final ValueChanged<String>? onConversationSelected;
  final ValueChanged<ConversationStartType>? onStartTypeSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCopy copy = AppCopy.of(context);
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> recent = ref.watch(
      recentConversationsControllerProvider,
    );
    final ConversationAccess? access = ref
        .watch(conversationAccessProvider)
        .value;
    final Set<String>? activeConversationIds = access?.enabled == true
        ? access!.activeConversations.map((item) => item.id).toSet()
        : null;
    final bool isRecentRefreshing = ref.watch(
      recentConversationsRefreshingProvider,
    );
    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: AppPrimaryButton(
          label: copy.homeEmptyTitle,
          leading: const Icon(Icons.add_rounded),
          onPressed: () => _showStartSheet(context, ref),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshHome(ref),
        child: CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          controller: MainTabScope.maybeOf(context)?.controllers[0],
          slivers: <Widget>[
            SliverToBoxAdapter(child: _HomeHeader(user: user)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.xl,
                AppSpacing.screenPadding,
                AppSpacing.sectionGap * 2,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  const LanguageSnackHomeSection(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      copy.todayTomatoLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.button.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _WeeklyTopicSection(
                    onSelected: (topic) =>
                        _startSuggestedTopic(context, ref, topic),
                  ),
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
                        return const SizedBox.shrink();
                      }
                      return _RecentConversations(
                        key: ValueKey('home-recent-${user?.id}'),
                        conversations: conversations,
                        activeConversationIds: activeConversationIds,
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
      ),
    );
  }

  Future<void> _refreshHome(WidgetRef ref) async {
    ref.invalidate(conversationAccessProvider);
    await ref.read(conversationAccessProvider.future);
    await ref.read(recentConversationsControllerProvider.notifier).reload();
    await Future.wait([
      ref.refresh(weeklyTopicsControllerProvider.future).then((_) {}),
      ref.refresh(languageSnacksControllerProvider.future).then((_) {}),
    ]);
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

  Future<void> _startSuggestedTopic(
    BuildContext context,
    WidgetRef ref,
    WeeklyTopic topic,
  ) async {
    if (ref.read(startConversationControllerProvider).isStarting) return;
    if (ref.read(conversationAccessProvider).value?.isLocked == true) {
      await showConversationAccessDialog(context);
      return;
    }
    final copy = AppCopy.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        alignment: const Alignment(0, -0.45),
        title: Text(copy.confirmSuggestedConversationTitle),
        content: Text(topic.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.startConversationLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (ref.read(startConversationControllerProvider).isStarting) return;
    final conversationId = await ref
        .read(startConversationControllerProvider.notifier)
        .startSuggestedFreeChat(topic.id);
    if (!context.mounted) return;
    if (conversationId != null) {
      onConversationSelected?.call(conversationId);
      return;
    }
    final failure = ref.read(startConversationControllerProvider).failureReason;
    if (failure == StartConversationFailureReason.slotsFull) {
      await showConversationAccessDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.of(context).failureMessage('freeChatRequestFailed'),
          ),
        ),
      );
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
  const _HomeHeader({required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: SizedBox(
                  width: 164,
                  height: 40,
                  child: Image.asset(
                    'logo_img/KakaoTalk_Photo_2026-10-08-22-20-21 002.png',
                    key: const ValueKey('home-brand-logo'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    semanticLabel: 'Toma Talk',
                  ),
                ),
              ),
            ),
          ),
          _LanguagePairBadge(language: user?.language),
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
          style: AppTypography.caption.copyWith(
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
    super.key,
    required this.conversations,
    required this.activeConversationIds,
    required this.isRefreshing,
    required this.onSelected,
    required this.onDelete,
  });
  final List<ConversationSummary> conversations;
  final Set<String>? activeConversationIds;
  final bool isRefreshing;
  final ValueChanged<String>? onSelected;
  final ValueChanged<ConversationSummary> onDelete;
  static const _colors = [AppPalette.blockLimeSoft, AppPalette.blockBlue];

  @override
  State<_RecentConversations> createState() => _RecentConversationsState();
}

class _RecentConversationsState extends State<_RecentConversations> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _RecentConversations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversations.length <= 5) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    bool isLocked(ConversationSummary item) =>
        widget.activeConversationIds == null
        ? item.locked
        : !widget.activeConversationIds!.contains(item.id);
    final orderedConversations = [
      ...widget.conversations.where((item) => !isLocked(item)),
      ...widget.conversations.where(isLocked),
    ];
    final visibleConversations = _expanded
        ? orderedConversations
        : orderedConversations.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isRefreshing)
          const Center(
            child: AppLoadingIndicator(
              key: ValueKey('recent-conversations-refresh-indicator'),
              width: 120,
            ),
          ),
        for (int index = 0; index < visibleConversations.length; index++) ...[
          RecentConversationCard(
            key: ValueKey(visibleConversations[index].id),
            category: copy.conversationCategory(
              visibleConversations[index].kind.name,
            ),
            title: visibleConversations[index].title,
            locked: isLocked(visibleConversations[index]),
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
        if (orderedConversations.length > 5) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              key: const ValueKey('home-conversations-expand'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _expanded
                    ? copy.showLessLabel
                    : copy.homeMoreConversations(
                        orderedConversations.length - 5,
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeeklyTopicSection extends ConsumerStatefulWidget {
  const _WeeklyTopicSection({required this.onSelected});

  final Future<void> Function(WeeklyTopic) onSelected;

  @override
  ConsumerState<_WeeklyTopicSection> createState() =>
      _WeeklyTopicSectionState();
}

class _WeeklyTopicSectionState extends ConsumerState<_WeeklyTopicSection>
    with WidgetsBindingObserver {
  bool _homeActive = true;
  String? _selectedTopicId;

  Future<void> _selectTopic(WeeklyTopic topic) async {
    if (_selectedTopicId != null) return;
    setState(() => _selectedTopicId = topic.id);
    try {
      await widget.onSelected(topic);
    } finally {
      if (mounted) setState(() => _selectedTopicId = null);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(weeklyTopicsControllerProvider.notifier).refreshIfNewWeek();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(weeklyTopicsControllerProvider.notifier).refreshIfNewWeek();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = (MainTabScope.maybeOf(context)?.index ?? 0) == 0;
    if (active && !_homeActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(weeklyTopicsControllerProvider.notifier).refreshIfNewWeek();
        }
      });
    }
    _homeActive = active;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics =
        ref.watch(weeklyTopicsControllerProvider).value?.topics ??
        const <WeeklyTopic>[];
    final isStarting = ref
        .watch(startConversationControllerProvider)
        .isStarting;
    if (topics.isEmpty && !isStarting) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: isStarting
          ? AppAsyncStateView.loading(
              key: const ValueKey('suggested-conversation-loading'),
              message: AppCopy.of(context).preparingSuggestedConversation,
            )
          : WeeklyTopicLoop(
              topics: topics,
              selectedTopicId: _selectedTopicId,
              onSelected: _selectTopic,
            ),
    );
  }
}
