class ConversationTextFormatter {
  const ConversationTextFormatter._();

  static String formatAssistantMessage(String value) {
    final String normalized = _normalizeInlineSpacing(value);
    if (normalized.contains('\n')) {
      return normalized;
    }

    final List<String> sentences = _splitSentences(normalized);
    if (sentences.length < 2) {
      return normalized;
    }

    return sentences.join('\n\n');
  }

  static String _normalizeInlineSpacing(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([.!?])(["”’)]?)(?=[A-Z])'),
          (Match match) => '${match.group(1)}${match.group(2)} ',
        );
  }

  static List<String> _splitSentences(String value) {
    final List<String> sentences = <String>[];
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < value.length; index += 1) {
      final String character = value[index];
      buffer.write(character);

      if (!_isSentenceEnd(character)) {
        continue;
      }

      while (index + 1 < value.length && _isClosingMark(value[index + 1])) {
        index += 1;
        buffer.write(value[index]);
      }

      final String sentence = buffer.toString().trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      buffer.clear();

      while (index + 1 < value.length && value[index + 1] == ' ') {
        index += 1;
      }
    }

    final String remainder = buffer.toString().trim();
    if (remainder.isNotEmpty) {
      sentences.add(remainder);
    }

    return sentences;
  }

  static bool _isSentenceEnd(String character) {
    return character == '.' || character == '!' || character == '?';
  }

  static bool _isClosingMark(String character) {
    return character == '"' ||
        character == '\'' ||
        character == '”' ||
        character == '’' ||
        character == ')';
  }
}
