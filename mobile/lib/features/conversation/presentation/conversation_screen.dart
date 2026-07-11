import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/application/conversation_controller.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  late final TextEditingController _composerController;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ConversationState> conversation = ref.watch(
      conversationControllerProvider(widget.conversationId),
    );
    final bool isSending = conversation.value?.isSending == true;

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        title: const Text('Conversation'),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: ChatComposer(
          controller: _composerController,
          enabled: conversation.hasValue,
          isSending: isSending,
          onSend: _sendMessage,
        ),
      ),
      body: conversation.when(
        loading: () =>
            const AppAsyncStateView.loading(message: 'Loading messages...'),
        error: (_, _) => AppAsyncStateView.error(
          title: 'Could not load this conversation.',
          message: 'Check your connection and try again.',
          onRetry: () => ref
              .read(
                conversationControllerProvider(widget.conversationId).notifier,
              )
              .reload(),
        ),
        data: (ConversationState state) => _ConversationMessageList(
          conversationId: widget.conversationId,
          state: state,
        ),
      ),
    );
  }

  void _sendMessage(String message) {
    _composerController.clear();
    unawaited(
      ref
          .read(conversationControllerProvider(widget.conversationId).notifier)
          .send(message),
    );
  }

  void _goBack() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(AppRoute.home);
  }
}

class _ConversationMessageList extends ConsumerWidget {
  const _ConversationMessageList({
    required this.conversationId,
    required this.state,
  });

  final String conversationId;
  final ConversationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.messages.isEmpty &&
        state.failedMessage == null &&
        state.errorMessage == null &&
        !state.isSending) {
      return const AppAsyncStateView.empty(
        title: 'No messages yet.',
        message: 'Send your first reply to begin practicing.',
      );
    }

    final List<Widget> children = <Widget>[
      const SizedBox(height: AppSpacing.lg),
      for (final ConversationMessage message in state.messages) ...<Widget>[
        ConversationMessageTile(message: message),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.isSending) ...<Widget>[
        const TypingIndicator(),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.failedMessage != null || state.errorMessage != null)
        _SendFailureCard(
          message: state.errorMessage ?? 'Message could not be sent.',
          onRetry: () => ref
              .read(conversationControllerProvider(conversationId).notifier)
              .retryFailedMessage(),
        ),
      const SizedBox(height: AppSpacing.xl),
    ];

    return ListView(children: children);
  }
}

class _SendFailureCard extends StatelessWidget {
  const _SendFailureCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppColorBlockCard(
      color: AppPalette.blockPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
