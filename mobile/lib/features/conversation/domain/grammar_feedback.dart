class GrammarFeedback {
  const GrammarFeedback({
    required this.id,
    required this.messageId,
    required this.originalText,
    required this.correctedText,
    required this.hasErrors,
    required this.errors,
    required this.createdAt,
  });

  factory GrammarFeedback.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Grammar feedback must be a JSON object.');
    }

    final Object? id = json['id'];
    final Object? messageId = json['message_id'];
    final Object? originalText = json['original_text'];
    final Object? correctedText = json['corrected_text'];
    final Object? hasErrors = json['has_errors'];
    final Object? errors = json['errors'];
    final DateTime? createdAt = DateTime.tryParse('${json['created_at']}');
    if (id is! String ||
        id.isEmpty ||
        messageId is! String ||
        messageId.isEmpty ||
        originalText is! String ||
        correctedText is! String ||
        hasErrors is! bool ||
        errors is! List ||
        createdAt == null) {
      throw const FormatException('Grammar feedback payload is invalid.');
    }

    return GrammarFeedback(
      id: id,
      messageId: messageId,
      originalText: originalText,
      correctedText: correctedText,
      hasErrors: hasErrors,
      errors: errors.map(GrammarError.fromJson).toList(growable: false),
      createdAt: createdAt,
    );
  }

  final String id;
  final String messageId;
  final String originalText;
  final String correctedText;
  final bool hasErrors;
  final List<GrammarError> errors;
  final DateTime createdAt;

  String get explanation {
    if (errors.isEmpty) {
      return hasErrors
          ? 'Review the corrected sentence and try saying it again.'
          : 'Your sentence sounds natural.';
    }
    return errors
        .map((GrammarError error) => error.explanation)
        .where((String explanation) => explanation.trim().isNotEmpty)
        .join('\n');
  }
}

class GrammarError {
  const GrammarError({
    required this.original,
    required this.corrected,
    required this.explanation,
  });

  factory GrammarError.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Grammar error must be a JSON object.');
    }

    final Object? original = json['original'];
    final Object? corrected = json['corrected'];
    final Object? explanation = json['explanation'];
    if (original is! String ||
        corrected is! String ||
        explanation is! String ||
        explanation.trim().isEmpty) {
      throw const FormatException('Grammar error payload is invalid.');
    }

    return GrammarError(
      original: original,
      corrected: corrected,
      explanation: explanation.trim(),
    );
  }

  final String original;
  final String corrected;
  final String explanation;
}
