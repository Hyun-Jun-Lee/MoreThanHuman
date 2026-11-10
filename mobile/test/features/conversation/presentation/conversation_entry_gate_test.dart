import 'dart:async';

import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lockedAccess = ConversationTurnAccess(
    enabled: true,
    userTurns: 0,
    canSend: false,
    locked: true,
  );

  testWidgets('direct entry waits for access and hides locked messages', (
    tester,
  ) async {
    final result = Completer<ConversationTurnAccess>();
    final repository = _FakeAccessRepository(() => result.future);
    await tester.pumpWidget(_app(repository));

    expect(repository.reads, 1);
    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.text('Loading messages...'), findsOneWidget);

    result.complete(lockedAccess);
    await tester.pumpAndSettle();
    expect(find.text('Locked conversation'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('active conversation opens after access is confirmed', (
    tester,
  ) async {
    final repository = _FakeAccessRepository(
      () async => const ConversationTurnAccess(
        enabled: true,
        userTurns: 0,
        canSend: true,
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pump();
    await tester.pump();

    expect(repository.reads, 1);
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(find.text('Locked conversation'), findsNothing);
  });

  testWidgets('failed access check blocks entry and can be retried', (
    tester,
  ) async {
    var calls = 0;
    final repository = _FakeAccessRepository(() async {
      if (calls++ == 0) throw StateError('offline');
      return lockedAccess;
    });
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.text('Could not load this conversation.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.reads, 2);
    expect(find.text('Locked conversation'), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
  });
}

Widget _app(ConversationAccessRepository repository) => ProviderScope(
  overrides: [
    conversationAccessRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(
    home: ConversationEntryGate(conversationId: 'conversation-id'),
  ),
);

class _FakeAccessRepository implements ConversationAccessRepository {
  _FakeAccessRepository(this.load);

  final Future<ConversationTurnAccess> Function() load;
  int reads = 0;

  @override
  Future<ConversationTurnAccess> getTurnAccess(String conversationId) {
    reads += 1;
    return load();
  }

  @override
  Future<ConversationAccess> getAccess() async =>
      const ConversationAccess.disabled();

  @override
  Future<void> activate(
    String conversationId, {
    String? replaceConversationId,
  }) async {}

  @override
  Future<void> deactivate(String conversationId) async {}
}
