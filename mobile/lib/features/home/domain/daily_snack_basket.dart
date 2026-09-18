import 'dart:math';

import 'package:curitalk/features/home/domain/language_snack.dart';

class DailySnackBasket {
  DailySnackBasket({
    required this.day,
    required List<LanguageSnack> snacks,
    this.consumed = 0,
  }) : snacks = List.unmodifiable(snacks);

  static const tomatoCount = 3;
  static const bitesPerTomato = 4;
  static const capacity = tomatoCount * bitesPerTomato;

  final String day;
  final List<LanguageSnack> snacks;
  final int consumed;
  bool get isFinished => consumed == capacity;

  static String dayOf(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static DailySnackBasket? create(
    List<LanguageSnack> source,
    DateTime now, {
    Random? random,
  }) {
    final unique = {for (final snack in source) snack.id: snack}.values.toList()
      ..shuffle(random);
    if (unique.isEmpty) return null;
    return DailySnackBasket(
      day: dayOf(now),
      snacks: List.generate(capacity, (i) => unique[i % unique.length]),
    );
  }

  DailySnackBasket withConsumed(int value) =>
      DailySnackBasket(day: day, snacks: snacks, consumed: value);

  Map<String, dynamic> toJson() => {
    'day': day,
    'consumed': consumed,
    'snacks': snacks.map((snack) => snack.toJson()).toList(),
  };

  factory DailySnackBasket.fromJson(Object? json, String language) {
    if (json is! Map<String, dynamic> ||
        json['day'] is! String ||
        json['consumed'] is! int ||
        json['snacks'] is! List) {
      throw const FormatException('Invalid daily snack basket.');
    }
    final consumed = json['consumed'] as int;
    final snacks = (json['snacks'] as List)
        .map(LanguageSnack.fromJson)
        .toList();
    if (consumed < 0 ||
        consumed > capacity ||
        snacks.length != capacity ||
        snacks.any((snack) => snack.contentLanguage != language)) {
      throw const FormatException('Invalid daily snack progress or language.');
    }
    return DailySnackBasket(
      day: json['day'] as String,
      snacks: snacks,
      consumed: consumed,
    );
  }
}
