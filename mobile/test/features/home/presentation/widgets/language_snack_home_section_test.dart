import 'dart:convert';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/application/daily_snack_basket_controller.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/domain/language_snack_repository.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_home_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../snack_test_fixtures.dart';

void main() {
  testWidgets('debug reset is available after all twelve snacks are consumed', (
    tester,
  ) async {
    final storage = MemorySnackStorage();
    storage.values['curitalk.snack_basket.v1.user.en'] = jsonEncode(
      DailySnackBasket(
        day: '2026-09-19',
        snacks: List.generate(12, testSnack),
        consumed: 12,
      ).toJson(),
    );
    await tester.pumpWidget(_app(storage, () => DateTime(2026, 9, 19)));
    await tester.pumpAndSettle();
    expect(find.text('12 / 12'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-snack-basket')));
    await tester.pumpAndSettle();
    expect(find.text('0 / 12'), findsOneWidget);
    expect(find.text('Refills at midnight'), findsNothing);
    final touch = find.byKey(const ValueKey('snack-tomato-touch'));
    await tester.tap(touch);
    await tester.pumpAndSettle();
    await tester.tap(touch);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('1 / 12'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-snack')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'debug reset refills locally and closes a partially eaten tomato',
    (tester) async {
      final storage = MemorySnackStorage();
      final resets = MemoryBasketResetRepository();
      storage.values['curitalk.snack_basket.v1.user.en'] = jsonEncode(
        DailySnackBasket(
          day: '2026-09-19',
          snacks: List.generate(12, testSnack),
          consumed: 5,
          resetId: 'already-applied',
        ).toJson(),
      );
      await tester.pumpWidget(
        _app(storage, () => DateTime(2026, 9, 19), resets: resets),
      );
      await tester.pumpAndSettle();
      final calls = resets.calls;
      final reset = find.byKey(const ValueKey('reset-snack-basket'));
      expect(find.byTooltip('Reset basket (test)'), findsOneWidget);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('0 / 12'), findsOneWidget);
      expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
      expect(resets.calls, calls);
      final stored = DailySnackBasket.fromJson(
        jsonDecode(storage.values['curitalk.snack_basket.v1.user.en']!),
        'en',
      );
      expect(stored.consumed, 0);
      expect(stored.resetId, 'already-applied');
      expect(
        stored.snacks.map((s) => s.id),
        List.generate(12, testSnack).map((s) => s.id),
      );
      final touch = find.byKey(const ValueKey('snack-tomato-touch'));
      await tester.tap(touch);
      await tester.pump();
      expect(tester.widget<IconButton>(reset).onPressed, isNull);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(reset).onPressed, isNotNull);
      await tester.tap(touch);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.widget<IconButton>(reset).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('close-snack')));
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('0 / 12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(storage, () => DateTime(2026, 9, 19), resets: resets),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup reset refills a persisted exhausted basket', (
    tester,
  ) async {
    final storage = MemorySnackStorage();
    storage.values['curitalk.snack_basket.v1.user.en'] = jsonEncode(
      DailySnackBasket(
        day: '2026-09-19',
        snacks: List.generate(12, testSnack),
        consumed: 12,
      ).toJson(),
    );
    final resets = MemoryBasketResetRepository()
      ..value = const SnackBasketReset(
        language: 'en',
        resetId: 'startup-reset',
      );
    await tester.pumpWidget(
      _app(storage, () => DateTime(2026, 9, 19), resets: resets),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
    expect(find.text('0 / 12'), findsOneWidget);
    expect(find.text('Refills at midnight'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LanguageSnackHomeSection)),
    );
    expect(
      container.read(dailySnackBasketProvider).value!.resetId,
      'startup-reset',
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'server reset is applied on resume and only after an open popup closes',
    (tester) async {
      final resets = MemoryBasketResetRepository();
      final storage = MemorySnackStorage();
      await tester.pumpWidget(
        _app(storage, () => DateTime(2026, 9, 19), resets: resets),
      );
      await tester.pumpAndSettle();
      final touch = find.byKey(const ValueKey('snack-tomato-touch'));
      await tester.tap(touch);
      await tester.pumpAndSettle();
      await tester.tap(touch);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      resets.value = const SnackBasketReset(
        language: 'en',
        resetId: 'remote-reset',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('1 / 12'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-snack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
      expect(find.text('0 / 12'), findsOneWidget);
      await tester.tap(touch);
      await tester.pumpAndSettle();
      await tester.tap(touch);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('close-snack')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('1 / 12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final resume in [false, true]) {
    testWidgets('exhausted basket resets at midnight (resume: $resume)', (
      tester,
    ) async {
      var now = DateTime(2026, 9, 18, 23, 59, 58);
      final storage = MemorySnackStorage();
      final basket = DailySnackBasket(
        day: '2026-09-18',
        snacks: List.generate(12, testSnack),
        consumed: 12,
      );
      storage.values['curitalk.snack_basket.v1.user.en'] = jsonEncode(
        basket.toJson(),
      );
      await tester.pumpWidget(_app(storage, () => now));
      await tester.pumpAndSettle();
      expect(find.text('Refills at midnight'), findsOneWidget);
      if (resume) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
      }
      now = DateTime(2026, 9, 19, 0, 0, 1);
      await tester.pump(const Duration(seconds: 3));
      if (resume) {
        expect(find.text('Refills at midnight'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
      expect(find.text('0 / 12'), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(LanguageSnackHomeSection)),
      );
      expect(c.read(dailySnackBasketProvider).value!.day, '2026-09-19');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'midnight waits for pickup to finish before replacing the basket',
    (tester) async {
      var now = DateTime(2026, 9, 18, 23, 59, 59, 800);
      await tester.pumpWidget(_app(MemorySnackStorage(), () => now));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LanguageSnackHomeSection)),
      );
      await tester.tap(find.byKey(const ValueKey('snack-tomato-touch')));
      await tester.pump();
      now = DateTime(2026, 9, 19);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('tomato-pickup')), findsOneWidget);
      expect(container.read(dailySnackBasketProvider).value!.day, '2026-09-18');
      await tester.pumpAndSettle();
      expect(container.read(dailySnackBasketProvider).value!.day, '2026-09-19');
      expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
      expect(find.text('0 / 12'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('midnight keeps an open popup until dismissed, then refills', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 18, 23, 59, 55);
    final storage = MemorySnackStorage();
    await tester.pumpWidget(_app(storage, () => now));
    await tester.pumpAndSettle();
    final touch = find.byKey(const ValueKey('snack-tomato-touch'));
    await tester.tap(touch);
    await tester.pumpAndSettle();
    await tester.tap(touch);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    now = DateTime(2026, 9, 19, 0, 0, 1);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-snack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
    expect(find.text('0 / 12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  MemorySnackStorage storage,
  DateTime Function() clock, {
  MemoryBasketResetRepository? resets,
}) => ProviderScope(
  overrides: [
    snackBasketResetRepositoryProvider.overrideWithValue(
      resets ?? MemoryBasketResetRepository(),
    ),
    snackClockProvider.overrideWithValue(clock),
    snackUserIdProvider.overrideWithValue('user'),
    languageSnackLanguageProvider.overrideWithValue('en'),
    languageSnacksEnabledProvider.overrideWithValue(true),
    secureStorageBackendProvider.overrideWithValue(storage),
    languageSnackRepositoryProvider.overrideWithValue(_Repository()),
    languageSnackCacheProvider.overrideWithValue(
      SecureLanguageSnackCache(storage),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: SingleChildScrollView(child: LanguageSnackHomeSection()),
    ),
  ),
);

class _Repository implements LanguageSnackRepository {
  @override
  Future<List<LanguageSnack>> listPublished() async =>
      List.generate(12, testSnack);
}
