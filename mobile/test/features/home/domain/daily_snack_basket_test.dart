import 'dart:math';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:flutter_test/flutter_test.dart';
import '../snack_test_fixtures.dart';

void main() {
  test(
    'randomly chooses twelve distinct IDs without truncating to latest first',
    () {
      final source = List.generate(30, testSnack);
      final basket = DailySnackBasket.create(
        source,
        DateTime(2026, 9, 18),
        random: Random(7),
      )!;
      expect(basket.snacks, hasLength(12));
      expect(basket.snacks.map((s) => s.id).toSet(), hasLength(12));
      expect(
        basket.snacks.any((s) => int.parse(s.id.split('-').last) >= 12),
        isTrue,
      );
      expect(source.first.id, 'en-0');
    },
  );
  test(
    'short lists repeat only after every distinct item; empty stays empty',
    () {
      expect(DailySnackBasket.create([], DateTime.now()), isNull);
      final basket = DailySnackBasket.create([
        testSnack(0),
        testSnack(1),
        testSnack(0),
      ], DateTime.now())!;
      expect(basket.snacks.take(2).map((s) => s.id).toSet(), hasLength(2));
      expect(basket.snacks[0], basket.snacks[2]);
    },
  );
  test('round trip validates language, capacity and progress', () {
    final basket = DailySnackBasket.create([
      testSnack(0),
    ], DateTime(2026, 9, 18))!.withConsumed(7);
    final decoded = DailySnackBasket.fromJson(basket.toJson(), 'en');
    expect(decoded.consumed, 7);
    expect(decoded.day, '2026-09-18');
    expect(
      () => DailySnackBasket.fromJson(basket.toJson(), 'ko'),
      throwsFormatException,
    );
    expect(
      () => DailySnackBasket.fromJson(basket.toJson()..['consumed'] = 13, 'en'),
      throwsFormatException,
    );
  });
}
