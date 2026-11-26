class SnackExpression {
  const SnackExpression({
    required this.expression,
    this.label,
    this.meaning,
    this.usage,
    this.example,
    this.exampleTranslation,
  });
  final String expression;
  final String? label;
  final String? meaning;
  final String? usage;
  final String? example;
  final String? exampleTranslation;

  Map<String, dynamic> toJson() => {
    'expression': expression,
    if (label != null) 'label': label,
    if (meaning != null) 'meaning': meaning,
    if (usage != null) 'usage': usage,
    if (example != null) 'example': example,
    if (exampleTranslation != null) 'example_translation': exampleTranslation,
  };
}

sealed class SnackPayload {
  const SnackPayload();
  List<SnackExpression> get expressions;
  Map<String, dynamic> toJson();
}

class ComparisonPayload extends SnackPayload {
  const ComparisonPayload(this.expressions);
  @override
  final List<SnackExpression> expressions;
  @override
  Map<String, dynamic> toJson() => {
    'items': expressions.map((item) => item.toJson()).toList(),
  };
}

final class RegionalPayload extends ComparisonPayload {
  const RegionalPayload(super.expressions, this.meaning);
  final String meaning;
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'meaning': meaning};
}

final class RegisterPayload extends ComparisonPayload {
  const RegisterPayload(super.expressions, this.situation);
  final String situation;
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'situation': situation};
}

final class CollocationPayload extends ComparisonPayload {
  const CollocationPayload(super.expressions, this.headword);
  final String headword;
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'headword': headword};
}

final class IdiomaticPayload extends SnackPayload {
  const IdiomaticPayload(this.item, this.literalMeaning);
  final SnackExpression item;
  final String literalMeaning;
  @override
  List<SnackExpression> get expressions => [item];
  @override
  Map<String, dynamic> toJson() => {
    ...item.toJson(),
    'literal_meaning': literalMeaning,
  };
}

class LanguageSnack {
  const LanguageSnack({
    required this.id,
    required this.contentType,
    required this.contentLanguage,
    required this.explanationLanguage,
    required this.payload,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static const supportedTypes = {
    'regional_variant',
    'usage_contrast',
    'homonym',
    'register_contrast',
    'collocation',
    'idiomatic_expression',
  };

  static bool isSupported(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['content_type'] is! String ||
        json['schema_version'] is! int) {
      throw const FormatException('Missing snack type or version.');
    }
    return supportedTypes.contains(json['content_type']) &&
        json['schema_version'] == 1;
  }

  factory LanguageSnack.fromJson(Object? json) {
    if (!isSupported(json)) {
      throw const FormatException('Unsupported snack type or version.');
    }
    final data = json as Map<String, dynamic>;
    final type = _text(data, 'content_type', 32);
    final raw = data['payload'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid snack payload.');
    }
    SnackExpression parseItem(Map<String, dynamic> item) => SnackExpression(
      expression: _text(item, 'expression', 80),
      label: {'regional_variant', 'register_contrast'}.contains(type)
          ? _text(item, 'label', 48)
          : null,
      meaning: {'homonym', 'collocation', 'idiomatic_expression'}.contains(type)
          ? _text(item, 'meaning', 160)
          : null,
      usage:
          {
            'usage_contrast',
            'register_contrast',
            'idiomatic_expression',
          }.contains(type)
          ? _text(item, 'usage', 160)
          : null,
      example: type != 'regional_variant' ? _text(item, 'example', 240) : null,
      exampleTranslation: item['example_translation'] == null
          ? null
          : _text(item, 'example_translation', 240),
    );
    final SnackPayload payload;
    if (type == 'idiomatic_expression') {
      if (raw.containsKey('items')) {
        throw const FormatException('An idiom has one expression, not items.');
      }
      payload = IdiomaticPayload(
        parseItem(raw),
        _text(raw, 'literal_meaning', 160),
      );
    } else {
      final rawItems = raw['items'];
      if (rawItems is! List || rawItems.length != 2) {
        throw const FormatException('A comparison needs two items.');
      }
      final items = List<SnackExpression>.unmodifiable(
        rawItems.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid snack item.');
          }
          return parseItem(item);
        }),
      );
      payload = switch (type) {
        'regional_variant' => RegionalPayload(
          items,
          _text(raw, 'meaning', 160),
        ),
        'register_contrast' => RegisterPayload(
          items,
          _text(raw, 'situation', 160),
        ),
        'collocation' => CollocationPayload(items, _text(raw, 'headword', 80)),
        _ => ComparisonPayload(items),
      };
    }
    final language = _text(data, 'content_language', 8);
    final explanation = _text(data, 'explanation_language', 8);
    if (!{'en', 'ko'}.contains(language) ||
        explanation != (language == 'en' ? 'ko' : 'en')) {
      throw const FormatException('Invalid snack language.');
    }
    return LanguageSnack(
      id: _text(data, 'id', 80),
      contentType: type,
      contentLanguage: language,
      explanationLanguage: explanation,
      payload: payload,
      publishedAt: _date(data, 'published_at'),
      createdAt: _date(data, 'created_at'),
      updatedAt: _date(data, 'updated_at'),
    );
  }

  final String id;
  final String contentType;
  final String contentLanguage;
  final String explanationLanguage;
  final SnackPayload payload;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<SnackExpression> get items => payload.expressions;
  String? get meaning => switch (payload) {
    RegionalPayload(:final meaning) => meaning,
    _ => null,
  };

  String get semanticLabel => contentType == 'regional_variant'
      ? '${items[0].label} ${items[0].expression}. ${items[1].label} ${items[1].expression}. $meaning'
      : [
          if (payload case RegisterPayload(:final situation)) situation,
          if (payload case CollocationPayload(:final headword)) headword,
          if (payload case IdiomaticPayload(:final literalMeaning))
            '${explanationLanguage == 'ko' ? '직역' : 'Literal meaning'}: $literalMeaning',
          for (final item in items)
            [
              item.label,
              item.expression,
              item.meaning,
              item.usage,
              item.example,
              item.exampleTranslation,
            ].whereType<String>().join('. '),
          ?meaning,
        ].join('. ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'content_type': contentType,
    'schema_version': 1,
    'content_language': contentLanguage,
    'explanation_language': explanationLanguage,
    'payload': payload.toJson(),
    'published_at': publishedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static String _text(Map<String, dynamic> data, String key, int max) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty || value.runes.length > max) {
      throw FormatException('Invalid snack $key.');
    }
    return value.trim();
  }

  static DateTime _date(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('Invalid snack $key.');
    }
    return DateTime.parse(value);
  }
}
