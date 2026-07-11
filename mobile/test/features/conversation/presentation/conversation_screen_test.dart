import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('explicit back button returns to Home when stack is empty', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.conversationPath('conversation-id'),
      routes: <RouteBase>[
        GoRoute(path: AppRoute.home, builder: (_, _) => const Text('Home')),
        GoRoute(
          path: '${AppRoute.conversation}/:conversationId',
          builder: (_, GoRouterState state) {
            return ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            const _FakeConversationRepository(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello!'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}

class _FakeConversationRepository implements ConversationRepository {
  const _FakeConversationRepository();

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return PaginatedMessages(
      results: <ConversationMessage>[
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: conversationId,
          role: ConversationMessageRole.assistant,
          content: 'Hello!',
          createdAt: DateTime.utc(2026, 7, 11),
        ),
      ],
      pagination: Pagination(
        limit: limit,
        offset: offset,
        totalCount: 1,
        hasMore: false,
      ),
    );
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
  }) {
    throw UnimplementedError();
  }
}
