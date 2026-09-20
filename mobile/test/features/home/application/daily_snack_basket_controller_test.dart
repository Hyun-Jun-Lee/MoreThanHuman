import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/application/daily_snack_basket_controller.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';
import 'dart:async';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/domain/language_snack_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../snack_test_fixtures.dart';

void main() {
  late MemorySnackStorage storage;
  late _Repository repository;
  late MemoryBasketResetRepository resets;
  late DateTime now;
  late String user;
  late String language;
  ProviderContainer create() => ProviderContainer(
    overrides: [
      snackBasketResetRepositoryProvider.overrideWithValue(resets),
      snackClockProvider.overrideWithValue(() => now),
      snackUserIdProvider.overrideWith((ref) => user),
      languageSnackLanguageProvider.overrideWith((ref) => language),
      languageSnacksEnabledProvider.overrideWithValue(true),
      secureStorageBackendProvider.overrideWithValue(storage),
      languageSnackRepositoryProvider.overrideWithValue(repository),
      languageSnackCacheProvider.overrideWith(
        (ref) => SecureLanguageSnackCache(
          storage,
          contentLanguage: ref.watch(languageSnackLanguageProvider),
        ),
      ),
    ],
  );
  setUp(() {
    storage = MemorySnackStorage();
    repository = _Repository();
    resets = MemoryBasketResetRepository();
    now = DateTime(2026, 9, 18);
    user = 'user-1';
    language = 'en';
  });

  test(
    'server reset applies once, survives restart and next-day refill',
    () async {
      final c = create();
      addTearDown(c.dispose);
      final first = (await c.read(dailySnackBasketProvider.future))!;
      final controller = c.read(dailySnackBasketProvider.notifier);
      for (var i = 0; i < 12; i++) {
        controller.takeBite();
      }
      resets.value = const SnackBasketReset(language: 'en', resetId: 'reset-1');
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 0);
      expect(
        c.read(dailySnackBasketProvider).value!.snacks.map((s) => s.id),
        first.snacks.map((s) => s.id),
      );
      controller.takeBite();
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
      await Future<void>.delayed(Duration.zero);
      final restarted = create();
      addTearDown(restarted.dispose);
      await restarted.read(dailySnackBasketProvider.future);
      await restarted.read(dailySnackBasketProvider.notifier).refreshReset();
      expect(restarted.read(dailySnackBasketProvider).value!.consumed, 1);
      now = DateTime(2026, 9, 19);
      restarted.read(dailySnackBasketProvider.notifier).ensureToday();
      await restarted.read(dailySnackBasketProvider.future);
      restarted.read(dailySnackBasketProvider.notifier).takeBite();
      await restarted.read(dailySnackBasketProvider.notifier).refreshReset();
      expect(restarted.read(dailySnackBasketProvider).value!.consumed, 1);
      expect(
        restarted.read(dailySnackBasketProvider).value!.resetId,
        'reset-1',
      );
    },
  );

  test(
    'local reset preserves server marker and rejects active interactions',
    () async {
      final c = create();
      addTearDown(c.dispose);
      final controller = c.read(dailySnackBasketProvider.notifier);
      expect(controller.resetForTesting(), isFalse);
      await c.read(dailySnackBasketProvider.future);
      resets.value = const SnackBasketReset(
        language: 'en',
        resetId: 'server-1',
      );
      await controller.refreshReset();
      for (var i = 0; i < 12; i++) {
        controller.takeBite();
      }
      controller.setInteractionActive(true);
      expect(controller.resetForTesting(), isFalse);
      expect(c.read(dailySnackBasketProvider).value!.consumed, 12);
      controller.setInteractionActive(false);
      final calls = resets.calls;
      expect(controller.resetForTesting(), isTrue);
      expect(resets.calls, calls);
      expect(c.read(dailySnackBasketProvider).value!.consumed, 0);
      expect(c.read(dailySnackBasketProvider).value!.resetId, 'server-1');
      controller.takeBite();
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
    },
  );

  test(
    'reset waits for interaction; network failure and wrong language retain progress',
    () async {
      final c = create();
      addTearDown(c.dispose);
      await c.read(dailySnackBasketProvider.future);
      final controller = c.read(dailySnackBasketProvider.notifier);
      controller.takeBite();
      resets.fail = true;
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
      resets.fail = false;
      resets.value = const SnackBasketReset(language: 'ko', resetId: 'wrong');
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
      controller.setInteractionActive(true);
      resets.value = const SnackBasketReset(language: 'en', resetId: 'new');
      await controller.refreshReset();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
      controller.setInteractionActive(false);
      expect(c.read(dailySnackBasketProvider).value!.consumed, 0);
    },
  );

  test('late reset response cannot reset a different account', () async {
    final c = create();
    addTearDown(c.dispose);
    await c.read(dailySnackBasketProvider.future);
    final pending = Completer<SnackBasketReset>();
    resets.pending = pending.future;
    final request = c.read(dailySnackBasketProvider.notifier).refreshReset();
    user = 'user-2';
    c.invalidate(snackUserIdProvider);
    await c.read(dailySnackBasketProvider.future);
    c.read(dailySnackBasketProvider.notifier).takeBite();
    pending.complete(
      const SnackBasketReset(language: 'en', resetId: 'old-user'),
    );
    await request;
    expect(c.read(dailySnackBasketProvider).value!.consumed, 1);
    expect(c.read(dailySnackBasketProvider).value!.resetId, isNull);
  });

  test(
    'twelve bites stay exhausted across restart until local midnight',
    () async {
      final c = create();
      addTearDown(c.dispose);
      final first = (await c.read(dailySnackBasketProvider.future))!;
      final controller = c.read(dailySnackBasketProvider.notifier);
      for (var i = 0; i < 12; i++) {
        expect(controller.takeBite()!.id, first.snacks[i].id);
      }
      expect(controller.takeBite(), isNull);
      controller.ensureToday();
      expect(c.read(dailySnackBasketProvider).value!.consumed, 12);
      expect(repository.calls, 1);
      await Future<void>.delayed(Duration.zero);
      final restarted = create();
      addTearDown(restarted.dispose);
      expect(
        (await restarted.read(dailySnackBasketProvider.future))!.consumed,
        12,
      );
      expect(
        restarted.read(dailySnackBasketProvider.notifier).takeBite(),
        isNull,
      );
      repository.snacks = List.generate(12, (i) => testSnack(100 + i));
      now = DateTime(2026, 9, 19);
      restarted.read(dailySnackBasketProvider.notifier).ensureToday();
      final next = (await restarted.read(dailySnackBasketProvider.future))!;
      expect(next.consumed, 0);
      expect(
        next.snacks.every((s) => int.parse(s.id.split('-').last) >= 100),
        isTrue,
      );
    },
  );

  test(
    'restart and feed refresh retain today; next date makes a new snapshot',
    () async {
      final c = create();
      final first = (await c.read(dailySnackBasketProvider.future))!;
      c.read(dailySnackBasketProvider.notifier).takeBite();
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      repository.snacks = List.generate(12, (i) => testSnack(100 + i));
      final restored = create();
      addTearDown(restored.dispose);
      final same = (await restored.read(dailySnackBasketProvider.future))!;
      expect(same.consumed, 1);
      expect(same.snacks.map((s) => s.id), first.snacks.map((s) => s.id));
      await restored.read(languageSnacksControllerProvider.future);
      expect(
        restored.read(dailySnackBasketProvider).value!.snacks.first.id,
        first.snacks.first.id,
      );
      now = DateTime(2026, 9, 19);
      restored.read(dailySnackBasketProvider.notifier).ensureToday();
      final next = (await restored.read(dailySnackBasketProvider.future))!;
      expect(next.day, '2026-09-19');
      expect(next.consumed, 0);
      expect(
        next.snacks.every((s) => int.parse(s.id.split('-').last) >= 100),
        isTrue,
      );
    },
  );

  test('user and language changes isolate progress', () async {
    final c = create();
    addTearDown(c.dispose);
    await c.read(dailySnackBasketProvider.future);
    c.read(dailySnackBasketProvider.notifier).takeBite();
    user = 'user-2';
    c.invalidate(snackUserIdProvider);
    expect((await c.read(dailySnackBasketProvider.future))!.consumed, 0);
    language = 'ko';
    repository.snacks = [testSnack(0, language: 'ko')];
    c.invalidate(languageSnackLanguageProvider);
    final korean = (await c.read(dailySnackBasketProvider.future))!;
    expect(korean.snacks.every((s) => s.contentLanguage == 'ko'), isTrue);
    expect(korean.consumed, 0);
  });

  test(
    'offline next day uses cached cards and storage errors do not block bites',
    () async {
      final c = create();
      addTearDown(c.dispose);
      await c.read(dailySnackBasketProvider.future);
      await Future<void>.delayed(Duration.zero);
      now = DateTime(2026, 9, 19);
      repository.fail = true;
      c.invalidate(languageSnacksControllerProvider);
      c.read(dailySnackBasketProvider.notifier).ensureToday();
      expect(
        (await c.read(dailySnackBasketProvider.future))!.snacks,
        hasLength(12),
      );
      storage.fail = true;
      expect(c.read(dailySnackBasketProvider.notifier).takeBite(), isNotNull);
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'empty feed and corrupt local record do not create fake cards',
    () async {
      storage.values['curitalk.snack_basket.v1.user-1.en'] = '{broken';
      repository.snacks = [];
      final c = create();
      addTearDown(c.dispose);
      expect(await c.read(dailySnackBasketProvider.future), isNull);
    },
  );
}

class _Repository implements LanguageSnackRepository {
  List<LanguageSnack> snacks = List.generate(12, testSnack);
  int calls = 0;
  bool fail = false;
  @override
  Future<List<LanguageSnack>> listPublished() async {
    calls++;
    if (fail) throw StateError('offline');
    return snacks;
  }
}
