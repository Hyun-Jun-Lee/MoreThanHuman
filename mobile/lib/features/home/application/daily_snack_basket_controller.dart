import 'dart:async';
import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/core/storage/snack_widget_bridge.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/application/snack_account_scope.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final snackClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final snackUserIdProvider = Provider<String?>((ref) {
  final configured = ref.watch(snackAccountScopeProvider);
  return configured?.userId ??
      ref.watch(authControllerProvider).value?.user?.id;
});
final snackWidgetEnabledProvider = Provider<bool>((ref) {
  final configured = ref.watch(snackAccountScopeProvider);
  return configured?.widgetEnabled ??
      (ref.watch(authControllerProvider).value?.isMember ?? false);
});

class DailySnackBasketController extends AsyncNotifier<DailySnackBasket?> {
  Future<void> _writes = Future.value();
  late String _key;
  late SecureStorageBackend _storage;
  late SnackWidgetBridge _widgetBridge;
  late String _userId;
  late String _language;
  int _generation = 0;
  int? _checkingGeneration;
  bool _interacting = false;
  String? _pendingResetId;
  String? _permissionScope;
  bool _unlimitedReplayEnabled = false;
  bool _widgetEnabled = false;

  @override
  Future<DailySnackBasket?> build() async {
    _generation++;
    _pendingResetId = null;
    _interacting = false;
    ref.onDispose(() => _generation++);
    final configuredAccount = ref.watch(snackAccountScopeProvider);
    final user = configuredAccount == null
        ? ref.watch(authControllerProvider.select((value) => value.value?.user))
        : null;
    final account =
        configuredAccount ??
        SnackAccountScope(
          userId: user?.id,
          language: user?.language.targetLanguage.code ?? 'en',
          widgetEnabled: user != null && !user.isGuest,
        );
    final userId = account.userId;
    _widgetEnabled = account.widgetEnabled;
    final language = account.language;
    final permissionScope = '$userId.$language';
    if (_permissionScope != permissionScope) {
      _permissionScope = permissionScope;
      _unlimitedReplayEnabled = false;
    }
    _storage = ref.watch(secureStorageBackendProvider);
    _widgetBridge = ref.watch(snackWidgetBridgeProvider);
    final storage = _storage;
    final now = ref.watch(snackClockProvider);
    if (userId == null) return null;
    _userId = userId;
    _language = language;
    final key =
        'curitalk.snack_basket.v1.${Uri.encodeComponent(userId)}.$language';
    _key = key;
    bool active = true;
    bool previousDay = false;
    String? resetId;
    ref.onDispose(() => active = false);
    await _writes;
    final widgetBasket = _widgetEnabled
        ? await _readWidgetBasket(userId, language)
        : null;
    if (!active) return null;
    if (widgetBasket != null &&
        widgetBasket.day == DailySnackBasket.dayOf(now())) {
      _persist(widgetBasket);
      return widgetBasket;
    }
    try {
      final raw = await storage.read(key);
      if (raw != null) {
        final restored = DailySnackBasket.fromJson(jsonDecode(raw), language);
        resetId = restored.resetId;
        if (restored.day == DailySnackBasket.dayOf(now())) {
          _persist(restored);
          return restored;
        }
        previousDay = true;
      }
    } on Object {
      // 저장소 오류나 이전 형식은 현재 피드 사용을 막지 않아요.
    }
    if (!active) return null;
    if (previousDay) {
      // 자정 직전 받은 목록도 새 날짜에는 다시 추첨해요.
      ref.invalidate(languageSnacksControllerProvider);
    } else {
      ref.read(languageSnacksControllerProvider.notifier).refreshIfStale();
    }
    final source = await ref.read(languageSnacksControllerProvider.future);
    if (!active) return null;
    final basket = DailySnackBasket.create(
      source.where((snack) => snack.contentLanguage == language).toList(),
      now(),
      resetId: resetId,
    );
    if (basket != null) _persist(basket);
    return basket;
  }

  Future<DailySnackBasket?> _readWidgetBasket(
    String userId,
    String language,
  ) async {
    try {
      final raw = await _widgetBridge.read();
      if (raw == null) return null;
      final snapshot = jsonDecode(raw);
      if (snapshot is! Map<String, dynamic> ||
          snapshot['user_id'] != userId ||
          snapshot['language'] != language) {
        return null;
      }
      return DailySnackBasket.fromJson(snapshot['basket'], language);
    } on Object {
      return null;
    }
  }

  Future<void> refreshFromWidget() async {
    if (state.isLoading ||
        state.value == null ||
        _interacting ||
        !_widgetEnabled ||
        ref.read(snackUserIdProvider) == null) {
      return;
    }
    final generation = _generation;
    await _writes;
    if (generation != _generation) return;
    final basket = await _readWidgetBasket(_userId, _language);
    if (generation != _generation || basket == null) return;
    if (basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      return;
    }
    final current = state.value;
    if (current == null ||
        current.day != basket.day ||
        current.consumed != basket.consumed ||
        current.resetId != basket.resetId ||
        !_sameSnacks(current, basket)) {
      state = AsyncData(basket);
      _persist(basket);
    }
  }

  bool _sameSnacks(DailySnackBasket a, DailySnackBasket b) {
    for (var i = 0; i < DailySnackBasket.capacity; i++) {
      if (a.snacks[i].id != b.snacks[i].id) {
        return false;
      }
    }
    return true;
  }

  void ensureToday() {
    if (state.isLoading) return;
    final basket = state.value;
    if (basket == null ||
        basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      ref.invalidateSelf();
    }
  }

  Future<void> refreshReset() async {
    final generation = _generation;
    if (_checkingGeneration == generation ||
        ref.read(snackUserIdProvider) == null) {
      return;
    }
    _checkingGeneration = generation;
    try {
      if (state.isLoading) await future;
      if (generation != _generation) return;
      final language = ref.read(languageSnackLanguageProvider);
      final marker = await ref.read(snackBasketResetRepositoryProvider).read();
      if (generation != _generation || marker.language != language) return;
      _unlimitedReplayEnabled = marker.unlimitedReplayEnabled;
      if (marker.resetId != null && marker.resetId != state.value?.resetId) {
        _pendingResetId = marker.resetId;
        await _applyPendingReset();
      }
      await _restartCompletedBasket();
      if (ref.mounted &&
          generation == _generation &&
          !state.isLoading &&
          state.value != null) {
        _persist(state.value!);
      }
    } on Object {
      // 오프라인·구 서버·인증 오류에는 저장된 진행을 그대로 유지해요.
    } finally {
      if (_checkingGeneration == generation) _checkingGeneration = null;
    }
  }

  void setInteractionActive(bool active) {
    _interacting = active;
    if (!active) {
      unawaited(_applyPendingReset());
      unawaited(_restartCompletedBasket());
    }
  }

  Future<void> _restartCompletedBasket() async {
    if (!_unlimitedReplayEnabled || _interacting || state.isLoading) return;
    final basket = state.value;
    if (basket == null ||
        !basket.isFinished ||
        basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      return;
    }
    await _redraw(basket);
  }

  bool resetForTesting() {
    if (!kDebugMode || _interacting || state.isLoading) return false;
    final basket = state.value;
    if (basket == null) return false;
    if (basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      ensureToday();
      return false;
    }
    unawaited(_redraw(basket));
    return true;
  }

  Future<void> _applyPendingReset() async {
    final resetId = _pendingResetId;
    if (_interacting || state.isLoading || resetId == null) return;
    final basket = state.value;
    if (basket == null) return;
    _pendingResetId = null;
    if (resetId == basket.resetId) return;
    await _redraw(basket, resetId: resetId);
  }

  Future<void> _redraw(DailySnackBasket previous, {String? resetId}) async {
    final generation = _generation;
    state = const AsyncLoading();
    try {
      ref.invalidate(languageSnacksControllerProvider);
      final source = await ref.read(languageSnacksControllerProvider.future);
      if (!ref.mounted || generation != _generation) return;
      final now = ref.read(snackClockProvider)();
      if (previous.day != DailySnackBasket.dayOf(now)) {
        ref.invalidateSelf();
        return;
      }
      final next = DailySnackBasket.create(
        source.where((snack) => snack.contentLanguage == _language).toList(),
        now,
        resetId: resetId ?? previous.resetId,
      );
      state = AsyncData(next ?? previous);
      if (next != null) _persist(next);
    } on Object {
      if (ref.mounted && generation == _generation) state = AsyncData(previous);
    }
  }

  LanguageSnack? takeBite() {
    if (state.isLoading) return null;
    final basket = state.value;
    if (basket == null ||
        basket.isFinished ||
        basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      ensureToday();
      return null;
    }
    final snack = basket.snacks[basket.consumed];
    final next = basket.withConsumed(basket.consumed + 1);
    state = AsyncData(next);
    _persist(next);
    return snack;
  }

  void _persist(DailySnackBasket basket) {
    final key = _key;
    final storage = _storage;
    final encoded = jsonEncode(basket.toJson());
    final widgetEncoded = jsonEncode({
      'user_id': _userId,
      'language': _language,
      'basket': basket.toJson(),
      'page': 0,
      'unlimited_replay_enabled': _unlimitedReplayEnabled,
    });
    final widgetBridge = _widgetBridge;
    final userId = _userId;
    final widgetEnabled = _widgetEnabled;
    _writes = _writes.then((_) async {
      try {
        await storage.write(key, encoded);
      } on Object {
        // 진행은 메모리에서 유지하며 저장 실패를 학습 실패로 처리하지 않아요.
      }
      try {
        if (widgetEnabled &&
            ref.mounted &&
            ref.read(snackUserIdProvider) == userId &&
            ref.read(snackWidgetEnabledProvider)) {
          await widgetBridge.write(widgetEncoded);
        }
      } on Object {
        // 위젯 저장 실패는 앱의 스낵 소비를 막지 않아요.
      }
    });
  }
}

final dailySnackBasketProvider =
    AsyncNotifierProvider<DailySnackBasketController, DailySnackBasket?>(
      DailySnackBasketController.new,
    );
