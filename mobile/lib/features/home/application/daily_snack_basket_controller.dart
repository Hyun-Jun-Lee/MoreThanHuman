import 'dart:async';
import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final snackClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final snackUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).value?.user?.id,
);

class DailySnackBasketController extends AsyncNotifier<DailySnackBasket?> {
  Future<void> _writes = Future.value();
  late String _key;
  late SecureStorageBackend _storage;
  int _generation = 0;
  int? _checkingGeneration;
  bool _interacting = false;
  String? _pendingResetId;

  @override
  Future<DailySnackBasket?> build() async {
    _generation++;
    _pendingResetId = null;
    _interacting = false;
    ref.onDispose(() => _generation++);
    final userId = ref.watch(snackUserIdProvider);
    final language = ref.watch(languageSnackLanguageProvider);
    _storage = ref.watch(secureStorageBackendProvider);
    final storage = _storage;
    final now = ref.watch(snackClockProvider);
    if (userId == null) return null;
    final key =
        'curitalk.snack_basket.v1.${Uri.encodeComponent(userId)}.$language';
    _key = key;
    bool active = true;
    bool previousDay = false;
    String? resetId;
    ref.onDispose(() => active = false);
    await _writes;
    try {
      final raw = await storage.read(key);
      if (raw != null) {
        final restored = DailySnackBasket.fromJson(jsonDecode(raw), language);
        resetId = restored.resetId;
        if (restored.day == DailySnackBasket.dayOf(now())) {
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
      if (marker.resetId != null && marker.resetId != state.value?.resetId) {
        _pendingResetId = marker.resetId;
        _applyPendingReset();
      }
    } on Object {
      // 오프라인·구 서버·인증 오류에는 저장된 진행을 그대로 유지해요.
    } finally {
      if (_checkingGeneration == generation) _checkingGeneration = null;
    }
  }

  void setInteractionActive(bool active) {
    _interacting = active;
    if (!active) _applyPendingReset();
  }

  bool resetForTesting() {
    if (!kDebugMode || _interacting || state.isLoading) return false;
    final basket = state.value;
    if (basket == null) return false;
    if (basket.day != DailySnackBasket.dayOf(ref.read(snackClockProvider)())) {
      ensureToday();
      return false;
    }
    final next = basket.withConsumed(0);
    state = AsyncData(next);
    _persist(next);
    return true;
  }

  void _applyPendingReset() {
    final resetId = _pendingResetId;
    if (_interacting || state.isLoading || resetId == null) return;
    final basket = state.value;
    if (basket == null) return;
    _pendingResetId = null;
    if (resetId == basket.resetId) return;
    final next = basket.reset(resetId);
    state = AsyncData(next);
    _persist(next);
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
    _writes = _writes.then((_) async {
      try {
        await storage.write(key, encoded);
      } on Object {
        // 진행은 메모리에서 유지하며 저장 실패를 학습 실패로 처리하지 않아요.
      }
    });
  }
}

final dailySnackBasketProvider =
    AsyncNotifierProvider<DailySnackBasketController, DailySnackBasket?>(
      DailySnackBasketController.new,
    );
