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

class LanguageSnack {
  const LanguageSnack({
    required this.id,
    required this.contentType,
    required this.contentLanguage,
    required this.explanationLanguage,
    required this.items,
    this.meaning,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static const supportedTypes = {
    'regional_variant',
    'usage_contrast',
    'homonym',
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
    final payload = data['payload'];
    if (payload is! Map<String, dynamic> || payload['items'] is! List) {
      throw const FormatException('Invalid snack payload.');
    }
    final rawItems = payload['items'] as List;
    if (rawItems.length != 2) {
      throw const FormatException('A snack needs two items.');
    }
    final items = rawItems
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid snack item.');
          }
          return SnackExpression(
            expression: _text(raw, 'expression', 80),
            label: type == 'regional_variant' ? _text(raw, 'label', 48) : null,
            meaning: type == 'homonym' ? _text(raw, 'meaning', 160) : null,
            usage: type == 'usage_contrast' ? _text(raw, 'usage', 160) : null,
            example: type != 'regional_variant'
                ? _text(raw, 'example', 240)
                : null,
            exampleTranslation: raw['example_translation'] == null
                ? null
                : _text(raw, 'example_translation', 240),
          );
        })
        .toList(growable: false);
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
      items: List.unmodifiable(items),
      meaning: type == 'regional_variant'
          ? _text(payload, 'meaning', 160)
          : null,
      publishedAt: _date(data, 'published_at'),
      createdAt: _date(data, 'created_at'),
      updatedAt: _date(data, 'updated_at'),
    );
  }

  final String id;
  final String contentType;
  final String contentLanguage;
  final String explanationLanguage;
  final List<SnackExpression> items;
  final String? meaning;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get semanticLabel => contentType == 'regional_variant'
      ? '${items[0].label} ${items[0].expression}. ${items[1].label} ${items[1].expression}. $meaning'
      : items
            .map(
              (item) =>
                  '${item.expression}. ${item.usage ?? item.meaning}. ${item.example}${item.exampleTranslation == null ? '' : '. ${item.exampleTranslation}'}',
            )
            .join(' ');

  Map<String, dynamic> toJson() => {
    'id': id,
    'content_type': contentType,
    'schema_version': 1,
    'content_language': contentLanguage,
    'explanation_language': explanationLanguage,
    'payload': {
      'items': items.map((item) => item.toJson()).toList(),
      if (meaning != null) 'meaning': meaning,
    },
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
