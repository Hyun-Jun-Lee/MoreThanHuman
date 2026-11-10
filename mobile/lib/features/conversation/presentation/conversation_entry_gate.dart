import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_access.dart';
import 'package:curitalk/features/conversation/presentation/conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 대화 화면을 만들기 전에 서버의 현재 잠금 상태를 확인해요.
class ConversationEntryGate extends ConsumerStatefulWidget {
  const ConversationEntryGate({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationEntryGate> createState() =>
      _ConversationEntryGateState();
}

class _ConversationEntryGateState extends ConsumerState<ConversationEntryGate> {
  late Future<ConversationTurnAccess> _accessFuture;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
  }

  @override
  void didUpdateWidget(covariant ConversationEntryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _accessFuture = _loadAccess();
    }
  }

  Future<ConversationTurnAccess> _loadAccess() => ref
      .read(conversationAccessRepositoryProvider)
      .getTurnAccess(widget.conversationId);

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return FutureBuilder<ConversationTurnAccess>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _statusScreen(
            copy,
            AppAsyncStateView.loading(message: copy.loadingMessages),
          );
        }
        if (snapshot.hasError) {
          return _statusScreen(
            copy,
            AppAsyncStateView.error(
              title: copy.loadConversationFailedTitle,
              message: copy.connectionRetryMessage,
              onRetry: () {
                final nextAccess = _loadAccess();
                setState(() {
                  _accessFuture = nextAccess;
                });
              },
            ),
          );
        }
        if (snapshot.data?.locked == true) {
          return _statusScreen(
            copy,
            AppAsyncStateView.empty(
              title: copy.lockedConversationLabel,
              message: copy.lockedConversationEntryMessage,
              icon: const Icon(Icons.lock_rounded, size: 40),
            ),
          );
        }
        return ConversationScreen(conversationId: widget.conversationId);
      },
    );
  }

  Widget _statusScreen(AppCopy copy, Widget body) => AppScaffold(
    appBar: AppBar(
      title: Text(copy.conversationTitle),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(AppRoute.home),
      ),
    ),
    body: body,
  );
}
