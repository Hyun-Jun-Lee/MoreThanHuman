import 'dart:async';
import 'package:curitalk/core/notifications/badge_sync_controller.dart';
import 'package:curitalk/core/notifications/ios_badge_bridge.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStorage implements SecureStorageBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class Bridge extends IOSBadgeBridge {
  final writes = <int>[];
  int requests = 0;
  BadgePermission state = BadgePermission.allowed;
  Completer<void>? block;
  @override
  Future<BadgePermission> permission({bool request = false}) async {
    if (request) {
      requests++;
      state = BadgePermission.allowed;
    }
    return state;
  }

  @override
  Future<void> setCount(int count) async {
    await block?.future;
    writes.add(count);
  }
}

class Repository
    implements ConversationRepository, UnreadConversationRepository {
  final queries = <Completer<bool>>[];
  final reads = <Completer<bool>>[];
  final batches = <List<String>>[];
  @override
  Future<bool> hasUnreadReplies() {
    final c = Completer<bool>();
    queries.add(c);
    return c.future;
  }

  @override
  Future<bool> markRepliesRead(String id, List<String> ids) {
    batches.add(ids);
    final c = Completer<bool>();
    reads.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Bridge bridge;
  late Repository repo;
  late MemoryStorage storage;
  late BadgeSyncController manager;
  setUp(() {
    bridge = Bridge();
    repo = Repository();
    storage = MemoryStorage();
    storage.values['badge.choice.member'] = 'enabled';
    manager = BadgeSyncController(bridge, storage, () => repo);
  });
  tearDown(() => manager.dispose());

  test('late unread response cannot undo a successful read', () async {
    manager.accountChanged('member', true);
    await settle();
    final read = manager.markRead('conversation', ['reply']);
    await settle();
    repo.reads.single.complete(false);
    await read;
    await settle();
    repo.queries.single.complete(true);
    await settle();
    expect(bridge.writes.last, 0);
    await manager.markRead('conversation', ['reply']);
    expect(repo.reads, hasLength(1));
  });
  test(
    'guest to member with same id discards old state and guest reads stay independent',
    () async {
      manager.accountChanged('member', false);
      await settle();
      expect(repo.queries, isEmpty);
      final read = manager.markRead('c', ['reply']);
      await settle();
      manager.accountChanged('member', true);
      repo.reads.single.complete(false);
      await read;
      await settle();
      repo.queries.last.complete(true);
      await settle();
      expect(bridge.writes.last, 1);
      manager.accountChanged('member', false);
      await settle();
      expect(bridge.writes.last, 0);
      expect(bridge.requests, 0);
    },
  );
  test('overlapping reads require a final authoritative query', () async {
    manager.accountChanged('member', true);
    await settle();
    repo.queries.single.complete(true);
    await settle();
    final a = manager.markRead('c', ['a']);
    final b = manager.markRead('c', ['b']);
    await settle();
    repo.reads[0].complete(false);
    await a;
    repo.reads[1].complete(true);
    await b;
    await settle();
    expect(repo.queries, hasLength(2));
    repo.queries.last.complete(false);
    await settle();
    expect(bridge.writes.last, 0);
  });
  test('logout clear follows an in-flight native write', () async {
    manager.accountChanged('member', true);
    await settle();
    bridge.block = Completer<void>();
    repo.queries.single.complete(true);
    await settle();
    manager.accountChanged(null, false);
    await settle();
    bridge.block!.complete();
    await settle();
    expect(bridge.writes.last, 0);
  });
  test(
    'failure retries and duplicates coalesce without blocking other work',
    () async {
      manager.accountChanged('guest', false);
      await settle();
      final a = manager.markRead('c', ['a']);
      await manager.markRead('c', ['a']);
      expect(repo.reads, hasLength(1));
      repo.reads.single.completeError(StateError('network'));
      await a;
      final retry = manager.markRead('c', ['a']);
      repo.reads.last.complete(false);
      await retry;
      expect(repo.reads, hasLength(2));
    },
  );
  test(
    'choice is per member and only explicit use requests permission',
    () async {
      bridge.state = BadgePermission.notDetermined;
      manager.accountChanged('guest', false);
      await settle();
      expect(await manager.needsChoice(), false);
      manager.accountChanged('new-member', true);
      await settle();
      expect(await manager.needsChoice(), true);
      await manager.choose(false);
      await settle();
      expect(await manager.needsChoice(), false);
      expect(bridge.requests, 0);
      await manager.choose(true);
      await settle();
      expect(bridge.requests, 1);
      manager.accountChanged('another-member', true);
      await settle();
      expect(await manager.needsChoice(), true);
    },
  );
}
