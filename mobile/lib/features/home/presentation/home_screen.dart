import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/presentation/widgets/recent_conversation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConversationStartType { freeChat, roleplay }

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
    final UserProfile? user = ref.watch(authControllerProvider).value?.user;
    final AsyncValue<List<ConversationSummary>> recent = ref.watch(
      recentConversationsControllerProvider,
    );
    final String firstName = _firstName(user?.name);

    return AppScaffold(
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      bottomNavigationBar: MainNavigationBar(
        destination: MainNavigationDestination.home,
        onDestinationSelected: (_) {},
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _HomeHeader(user: user)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.xl,
              AppSpacing.screenPadding,
              AppSpacing.sectionGap,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                Text('Hi, $firstName', style: AppTypography.displayLg),
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: 'START CONVERSATION',
                  expand: false,
                  leading: const Icon(Icons.add_rounded),
                  onPressed: () => _showStartSheet(context),
                ),
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
                    if (conversations.isEmpty) {
                      return _EmptyHome(
                        onStart: () => _showStartSheet(context),
                      );
                    }
                    return _RecentConversations(
                      conversations: conversations,
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
    final ConversationStartType?
    selected = await showAppModalSheet<ConversationStartType>(
      context: context,
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: AppSpacing.xxl,
                height: AppSpacing.xxs,
                decoration: const BoxDecoration(
                  color: AppPalette.hairline,
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Start a conversation', style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.lg),
            AppSelectionCard(
              title: 'Free Chat',
              description: 'Bring your own topic',
              icon: const Icon(Icons.forum_outlined),
              selected: false,
              onTap: () =>
                  Navigator.pop(sheetContext, ConversationStartType.freeChat),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSelectionCard(
              title: 'Roleplay',
              description: 'Practice a real-world situation',
              icon: const Icon(Icons.theater_comedy_outlined),
              selected: false,
              onTap: () =>
                  Navigator.pop(sheetContext, ConversationStartType.roleplay),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      onStartTypeSelected?.call(selected);
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
  const _HomeHeader({required this.user});

  final UserProfile? user;

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
          const Icon(Icons.menu_rounded),
          const Expanded(
            child: Text(
              'CURITALK',
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd,
            ),
          ),
          Semantics(
            label: 'Profile for ${user?.name ?? 'user'}',
            child: CircleAvatar(
              radius: AppSize.iconButton / 2,
              backgroundColor: AppPalette.blockPink,
              child: Text(initial, style: AppTypography.button),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentConversations extends StatelessWidget {
  const _RecentConversations({
    required this.conversations,
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
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppSectionLabel('Recent'),
        const SizedBox(height: AppSpacing.lg),
        for (int index = 0; index < conversations.length; index++) ...<Widget>[
          RecentConversationCard(
            category: conversations[index].category,
            title: conversations[index].title,
            preview: conversations[index].preview,
            color: _colors[index % _colors.length],
            onTap: onSelected == null
                ? null
                : () => onSelected!(conversations[index].id),
          ),
          if (index != conversations.length - 1)
            const SizedBox(height: AppSpacing.md),
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
