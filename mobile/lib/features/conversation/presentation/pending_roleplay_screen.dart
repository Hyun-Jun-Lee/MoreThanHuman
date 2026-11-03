import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/application/start_conversation_controller.dart';
import 'package:curitalk/features/conversation/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 영속 대화가 생성되기 전 역할극 첫 인사를 보여줘요.
class PendingRoleplayScreen extends ConsumerStatefulWidget {
  const PendingRoleplayScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<PendingRoleplayScreen> createState() =>
      _PendingRoleplayScreenState();
}

class _PendingRoleplayScreenState extends ConsumerState<PendingRoleplayScreen> {
  late final StartConversationController _startController;
  late final StartStreamPreviewController _previewController;
  final TextEditingController _composerController = TextEditingController();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _startController = ref.read(startConversationControllerProvider.notifier);
    _previewController = ref.read(
      startStreamPreviewProvider(widget.requestId).notifier,
    );
  }

  @override
  void dispose() {
    unawaited(_startController.cancelSuggestedStreamFor(widget.requestId));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _previewController.clear(),
    );
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final preview = ref.watch(startStreamPreviewProvider(widget.requestId));
    if (!_leaving) {
      if (preview == null) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoute.roleplaySetup);
          }
        });
      } else if (preview.conversationId case final conversationId?) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) openStartedConversation(context, conversationId);
        });
      } else if (preview.hasFailed) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
        });
      }
    }

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: copy.backLabel,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(copy.conversationTitle),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: ChatComposer(
          controller: _composerController,
          enabled: false,
          isSending: true,
          onSend: (_) {},
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (preview?.assistantText.isNotEmpty == true) ...<Widget>[
            ChatBubble(
              message: preview!.assistantText,
              speaker: ChatSpeaker.assistant,
              typing: true,
              minVisibleChars: preview.minVisibleAssistantChars,
              onVisibleChars: (count) => _startController
                  .onConversationFrameReady(widget.requestId, count),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (preview?.isActive != false) const TypingIndicator(),
        ],
      ),
    );
  }
}
