import 'dart:async';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/history/data/conversation_history_repository.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late _Repository repository;
  setUp(() async {
    repository = _Repository();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        conversationHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.listen(conversationHistoryControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    await container.read(conversationHistoryControllerProvider.future);
  });
  tearDown(() => container.dispose());

  test(
    'loads beyond five, prevents concurrent requests and deduplicates pages',
    () async {
      final controller = container.read(
        conversationHistoryControllerProvider.notifier,
      );
      expect(
        container.read(conversationHistoryControllerProvider).value!.page.items,
        hasLength(20),
      );
      final pending = controller.loadMore();
      await controller.loadMore();
      expect(repository.offsets, [0, 20]);
      repository.pending.complete(
        ConversationPage(
          items: [_item(19), _item(20)],
          nextOffset: 22,
          hasMore: false,
        ),
      );
      await pending;
      final page = container
          .read(conversationHistoryControllerProvider)
          .value!
          .page;
      expect(page.items, hasLength(21));
      expect(page.hasMore, isFalse);
      await controller.loadMore();
      expect(repository.offsets, [0, 20]);
    },
  );

  test(
    'additional page failure keeps the list and retries the same offset',
    () async {
      final controller = container.read(
        conversationHistoryControllerProvider.notifier,
      );
      final pending = controller.loadMore();
      repository.pending.completeError(StateError('offline'));
      await pending;
      expect(
        container
            .read(conversationHistoryControllerProvider)
            .value!
            .loadMoreFailed,
        isTrue,
      );
      expect(
        container.read(conversationHistoryControllerProvider).value!.page.items,
        hasLength(20),
      );
      repository.pending = Completer();
      final retry = controller.loadMore();
      repository.pending.complete(
        ConversationPage(items: [_item(20)], nextOffset: 21, hasMore: false),
      );
      await retry;
      expect(repository.offsets, [0, 20, 20]);
      expect(
        container
            .read(conversationHistoryControllerProvider)
            .value!
            .loadMoreFailed,
        isFalse,
      );
    },
  );

  test(
    'refresh reloads the already read range so the scroll target stays available',
    () async {
      final pending = container
          .read(conversationHistoryControllerProvider.notifier)
          .loadMore();
      repository.pending.complete(
        ConversationPage(items: [_item(20)], nextOffset: 21, hasMore: false),
      );
      await pending;
      container.invalidate(conversationHistoryControllerProvider);
      final refreshed = await container.read(
        conversationHistoryControllerProvider.future,
      );
      expect(refreshed.page.items.last.id, '20');
      expect(repository.offsets, [0, 20, 0, 20]);
    },
  );

  test('logout discards a delayed page from the previous account', () async {
    final pending = container
        .read(conversationHistoryControllerProvider.notifier)
        .loadMore();
    (container.read(authControllerProvider.notifier) as _Auth).signOut();
    await container.pump();
    await container.read(conversationHistoryControllerProvider.future);
    repository.pending.complete(
      ConversationPage(items: [_item(20)], nextOffset: 21, hasMore: false),
    );
    await pending;
    expect(
      container.read(conversationHistoryControllerProvider).value!.page.items,
      isEmpty,
    );
  });

  test('refresh discards an obsolete pagination response', () async {
    final pending = container
        .read(conversationHistoryControllerProvider.notifier)
        .loadMore();
    container.invalidate(conversationHistoryControllerProvider);
    await container.read(conversationHistoryControllerProvider.future);
    repository.pending.complete(
      ConversationPage(items: [_item(20)], nextOffset: 21, hasMore: false),
    );
    await pending;
    expect(
      container.read(conversationHistoryControllerProvider).value!.page.items,
      hasLength(20),
    );
  });
}

ConversationSummary _item(int i) => ConversationSummary(
  id: '$i',
  title: 'Conversation $i',
  kind: ConversationKind.freeChat,
  messageCount: 2,
  isActive: true,
  updatedAt: DateTime(2026),
);

class _Repository implements ConversationHistoryRepository {
  final offsets = <int>[];
  Completer<ConversationPage> pending = Completer();
  @override
  Future<ConversationPage> list({int offset = 0, int limit = 20}) {
    offsets.add(offset);
    if (offset > 0) return pending.future;
    return Future.value(
      ConversationPage(
        items: List.generate(20, _item),
        nextOffset: 20,
        hasMore: true,
      ),
    );
  }
}

class _Auth extends AuthController {
  @override
  Future<AuthSession> build() async => AuthSession.authenticated(
    UserProfile(
      id: 'user',
      email: 'a@example.com',
      name: 'A',
      isActive: true,
      oauthProvider: 'google',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  void signOut() => state = const AsyncData(AuthSession.unauthenticated());
}
