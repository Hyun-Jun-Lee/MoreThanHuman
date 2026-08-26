import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:curitalk/features/home/presentation/account_sheet.dart';
import 'package:curitalk/features/home/presentation/conversation_start_sheet.dart';
import 'package:curitalk/features/home/presentation/widgets/recent_conversation_card.dart';
import 'package:curitalk/features/language/language.dart';
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
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> recent = ref.watch(
      recentConversationsControllerProvider,
    );
    final bool isRecentRefreshing = ref.watch(
      recentConversationsRefreshingProvider,
    );
    final String firstName = _firstName(user?.name);

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Start conversation',
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
                Text('Hi, $firstName', style: AppTypography.displayLg),
                const SizedBox(height: AppSpacing.xxl),
                recent.when(
                  loading: () => const AppAsyncStateView.loading(
                    message: 'Loading recent conversations...',
                  ),
                  error: (_, _) => AppAsyncStateView.error(
                    message: 'Recent conversations could not be loaded.',
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
                        return const AppAsyncStateView.loading(
                          message: 'Updating conversations...',
                        );
                      }
                      return _EmptyHome(
                        onStart: () => _showStartSheet(context),
                      );
                    }
                    return _RecentConversations(
                      conversations: conversations,
                      isRefreshing: isRefreshing,
                      onSelected: onConversationSelected,
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

  static String _firstName(String? name) {
    final String normalized = name?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'there';
    }
    return normalized.split(RegExp(r'\s+')).first;
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
            label: 'Profile for ${user?.name ?? 'user'}',
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

  @override
  State<_RecentConversations> createState() => _RecentConversationsState();
}

class _RecentConversationsState extends State<_RecentConversations> {
  static const int _collapsedCount = 4;

  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
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
            const AppSectionLabel('Recent'),
            if (widget.isRefreshing) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label: 'Updating conversations',
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
            category: visibleConversations[index].category,
            title: visibleConversations[index].title,
            preview: visibleConversations[index].preview,
            color: _RecentConversations
                ._colors[index % _RecentConversations._colors.length],
            onTap: widget.onSelected == null
                ? null
                : () => widget.onSelected!(visibleConversations[index].id),
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
              label: Text(_isExpanded ? 'SHOW LESS' : 'SHOW ALL'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'Welcome to Curitalk',
          textAlign: TextAlign.center,
          style: AppTypography.headlineLg,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your conversation canvas is clear. What would you like to explore today?',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppColorBlockCard(
          color: AppPalette.blockLime,
          child: Column(
            children: <Widget>[
              AppSectionLabel('Suggested starting points'),
              SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  Chip(label: Text('PLAN TRAVEL')),
                  Chip(label: Text('BASEBALL STATS')),
                  Chip(label: Text('AI NEWS')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'START CONVERSATION',
          leading: const Icon(Icons.add_rounded),
          onPressed: onStart,
        ),
      ],
    );
  }
}
