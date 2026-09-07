class LanguageSnack {
  const LanguageSnack({
    required this.id,
    required this.category,
    required this.leftLabel,
    required this.leftWord,
    required this.rightLabel,
    required this.rightWord,
    required this.meaning,
    required this.example,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LanguageSnack.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Language snack must be a JSON object.');
    }

    return LanguageSnack(
      id: _requiredText(json, 'id'),
      category: _requiredText(json, 'category'),
      leftLabel: _requiredText(json, 'left_label'),
      leftWord: _requiredText(json, 'left_word'),
      rightLabel: _requiredText(json, 'right_label'),
      rightWord: _requiredText(json, 'right_word'),
      meaning: _requiredText(json, 'meaning'),
      example: _requiredText(json, 'example'),
      publishedAt: _requiredDateTime(json, 'published_at'),
      createdAt: _requiredDateTime(json, 'created_at'),
      updatedAt: _requiredDateTime(json, 'updated_at'),
    );
  }

  final String id;
  final String category;
  final String leftLabel;
  final String leftWord;
  final String rightLabel;
  final String rightWord;
  final String meaning;
  final String example;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, String> toJson() => <String, String>{
    'id': id,
    'category': category,
    'left_label': leftLabel,
    'left_word': leftWord,
    'right_label': rightLabel,
    'right_word': rightWord,
    'meaning': meaning,
    'example': example,
    'published_at': publishedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static String _requiredText(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Language snack $field is invalid.');
    }
    return value.trim();
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is! String) {
      throw FormatException('Language snack $field is invalid.');
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Language snack $field is invalid.');
    }
    return parsed;
  }
}
