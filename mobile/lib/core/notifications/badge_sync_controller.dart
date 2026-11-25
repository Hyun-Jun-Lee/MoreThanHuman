import 'dart:async';

import 'package:curitalk/core/notifications/ios_badge_bridge.dart';
import 'package:curitalk/core/storage/storage_providers.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/data/api_conversation_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 읽음·조회·native 쓰기를 대화 진행과 독립적으로 조정해요.
class BadgeSyncController {
  BadgeSyncController(this.bridge, this.storage, this.repository);
  final IOSBadgeBridge bridge;
  final SecureStorageBackend storage;
  final ConversationRepository Function() repository;
  String? _user;
  bool _member = false;
  bool _enabled = false;
  bool _allowed = false;
  bool _disposed = false;
  int _account = 0;
  int _generation = 0;
  int _mutations = 0;
  bool _dirty = false;
  bool _needsFinalQuery = false;
  bool _running = false;
  Future<void> _writes = Future.value();
  final Map<String, Set<String>> _read = {};
  final Map<String, Set<String>> _reading = {};

  bool _valid(int account, int generation) =>
      !_disposed && account == _account && generation == _generation;

  void dispose() {
    _disposed = true;
    _account++;
  }

  void accountChanged(String? user, bool member) {
    if (_user == user && _member == member) return;
    _user = user;
    _member = member;
    _enabled = false;
    _allowed = false;
    _account++;
    _generation++;
    _read.clear();
    _reading.clear();
    final account = _account;
    // 이전 쓰기가 진행 중이어도 지우기를 그 뒤에 직렬로 예약해요.
    _writes = _writes.then((_) async {
      if (_disposed || account != _account) return;
      try {
        if (await bridge.permission() == BadgePermission.allowed) {
          await bridge.setCount(0);
        }
      } catch (_) {}
    });
    refresh();
  }

  Future<bool> needsChoice() async {
    final account = _account;
    final user = _user;
    if (!_member || user == null) return false;
    final permission = await bridge.permission();
    final choice = await storage.read('badge.choice.$user');
    return account == _account &&
        _member &&
        permission != BadgePermission.unsupported &&
        choice == null;
  }

  Future<BadgePermission> choose(bool enabled) async {
    final user = _user;
    final account = _account;
    if (!_member || user == null) return BadgePermission.unsupported;
    await storage.write('badge.choice.$user', enabled ? 'enabled' : 'disabled');
    if (account != _account) return BadgePermission.unsupported;
    var permission = await bridge.permission();
    if (enabled &&
        permission == BadgePermission.notDetermined &&
        account == _account) {
      permission = await bridge.permission(request: true);
    }
    if (account == _account) refresh();
    return permission;
  }

  void refresh() {
    if (_disposed) return;
    _generation++;
    if (_mutations != 0) _needsFinalQuery = true;
    _dirty = true;
    scheduleMicrotask(_sync);
  }

  Future<void> _sync() async {
    if (_disposed || _running || !_dirty || _mutations != 0) return;
    _running = true;
    _dirty = false;
    final account = _account;
    final generation = _generation;
    try {
      final permission = await bridge.permission();
      final user = _user;
      final enabled =
          _member &&
          user != null &&
          await storage.read('badge.choice.$user') == 'enabled';
      if (!_valid(account, generation)) return;
      _allowed = permission == BadgePermission.allowed;
      _enabled = enabled;
      if (!_allowed) return;
      if (!enabled) {
        _write(0, account, generation);
        return;
      }
      final repo = repository();
      if (repo is! UnreadConversationRepository) return;
      final unread = await (repo as UnreadConversationRepository)
          .hasUnreadReplies();
      if (_valid(account, generation) && _mutations == 0) {
        _write(unread ? 1 : 0, account, generation);
      }
    } catch (_) {
      // 다음 앱 복귀·읽음·완료 이벤트에서 재시도해요.
    } finally {
      _running = false;
      if (_dirty && !_disposed) scheduleMicrotask(_sync);
    }
  }

  void _write(int count, int account, int generation) {
    _writes = _writes.then((_) async {
      if (!_valid(account, generation) ||
          !_allowed ||
          (count == 1 && (!_member || !_enabled))) {
        return;
      }
      try {
        await bridge.setCount(count);
      } catch (_) {}
    });
  }

  Future<void> markRead(String conversation, Iterable<String> ids) async {
    final repo = repository();
    if (_user == null || repo is! UnreadConversationRepository) return;
    final done = _read.putIfAbsent(conversation, () => {});
    final pending = _reading.putIfAbsent(conversation, () => {});
    final batch = ids
        .where((id) => !done.contains(id) && !pending.contains(id))
        .take(100)
        .toList();
    if (batch.isEmpty) return;
    pending.addAll(batch);
    final account = _account;
    final generation = ++_generation;
    if (_mutations != 0) _needsFinalQuery = true;
    _mutations++;
    try {
      final unread = await (repo as UnreadConversationRepository)
          .markRepliesRead(conversation, batch);
      if (account == _account) done.addAll(batch);
      if (_valid(account, generation) && _mutations == 1 && !_needsFinalQuery) {
        _dirty = _member && (!_enabled || !_allowed);
        if (_member && _enabled && _allowed) {
          _write(unread ? 1 : 0, account, generation);
        }
      } else {
        _dirty = true;
      }
    } catch (_) {
      // 읽음 실패는 대화 오류로 전파하지 않고 다음 공개·복귀에 재시도해요.
      _dirty = true;
    } finally {
      pending.removeAll(batch);
      _mutations--;
      if (_mutations == 0) _needsFinalQuery = false;
      if (_dirty) scheduleMicrotask(_sync);
    }
  }

  Future<T> mutation<T>(Future<T> Function() operation) async {
    _generation++;
    _mutations++;
    try {
      return await operation();
    } finally {
      _mutations--;
      refresh();
    }
  }
}

final badgeSyncControllerProvider = Provider<BadgeSyncController>((ref) {
  final controller = BadgeSyncController(
    ref.watch(iosBadgeBridgeProvider),
    ref.watch(secureStorageBackendProvider),
    () => ref.read(conversationRepositoryProvider),
  );
  ref.listen(authControllerProvider, (_, next) {
    if (next.isLoading || next.hasError) return;
    final session = next.value;
    controller.accountChanged(session?.user?.id, session?.isMember == true);
  }, fireImmediately: true);
  ref.onDispose(controller.dispose);
  return controller;
});
