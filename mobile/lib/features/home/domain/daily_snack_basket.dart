import 'dart:math';

import 'package:curitalk/features/home/domain/language_snack.dart';

class DailySnackBasket {
  DailySnackBasket({
    required this.day,
    required List<LanguageSnack> snacks,
    List<LanguageSnack>? candidates,
    this.consumed = 0,
    this.resetId,
  }) : snacks = List.unmodifiable(snacks),
       candidates = List.unmodifiable(candidates ?? snacks);

  static const categoryOrder = [
    'regional_variant',
    'usage_contrast',
    'homonym',
    'register_contrast',
    'collocation',
    'idiomatic_expression',
  ];
  static const tomatoCount = 3;
  static const bitesPerTomato = 4;
  static const capacity = tomatoCount * bitesPerTomato;

  final String day;
  final List<LanguageSnack> snacks;
  final List<LanguageSnack> candidates;
  final int consumed;
  final String? resetId;
  bool get isFinished => consumed == capacity;

  static String dayOf(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static DailySnackBasket? create(
    List<LanguageSnack> source,
    DateTime now, {
    Random? random,
    String? resetId,
  }) {
    final unique = {for (final snack in source) snack.id: snack}.values.toList()
      ..shuffle(random);
    if (unique.isEmpty) return null;
    final groups = {
      for (final kind in categoryOrder)
        kind: unique.where((snack) => snack.contentType == kind).toList(),
    };
    final available = categoryOrder
        .where((kind) => groups[kind]!.isNotEmpty)
        .toList();
    if (available.isEmpty) return null;
    return DailySnackBasket(
      day: dayOf(now),
      resetId: resetId,
      candidates: unique,
      snacks: List.generate(capacity, (i) {
        final group = groups[available[i % available.length]]!;
        return group[(i ~/ available.length) % group.length];
      }),
    );
  }

  DailySnackBasket withConsumed(int value) => DailySnackBasket(
    day: day,
    snacks: snacks,
    candidates: candidates,
    consumed: value,
    resetId: resetId,
  );

  DailySnackBasket reset(String id) => DailySnackBasket(
    day: day,
    snacks: snacks,
    candidates: candidates,
    resetId: id,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'consumed': consumed,
    'reset_id': resetId,
    'snacks': snacks.map((snack) => snack.toJson()).toList(),
    'candidates': candidates.map((snack) => snack.toJson()).toList(),
  };

  factory DailySnackBasket.fromJson(Object? json, String language) {
    if (json is! Map<String, dynamic> ||
        json['day'] is! String ||
        json['consumed'] is! int ||
        json['snacks'] is! List ||
        (json['candidates'] != null && json['candidates'] is! List) ||
        (json['reset_id'] != null && json['reset_id'] is! String)) {
      throw const FormatException('Invalid daily snack basket.');
    }
    final consumed = json['consumed'] as int;
    final snacks = (json['snacks'] as List)
        .map(LanguageSnack.fromJson)
        .toList();
    final candidates = json['candidates'] == null
        ? snacks
        : (json['candidates'] as List).map(LanguageSnack.fromJson).toList();
    if (candidates.isEmpty ||
        candidates.length > 30 ||
        candidates.any((snack) => snack.contentLanguage != language) ||
        consumed < 0 ||
        consumed > capacity ||
        snacks.length != capacity ||
        snacks.any((snack) => snack.contentLanguage != language)) {
      throw const FormatException('Invalid daily snack progress or language.');
    }
    return DailySnackBasket(
      day: json['day'] as String,
      snacks: snacks,
      candidates: candidates,
      consumed: consumed,
      resetId: json['reset_id'] as String?,
    );
  }
}
