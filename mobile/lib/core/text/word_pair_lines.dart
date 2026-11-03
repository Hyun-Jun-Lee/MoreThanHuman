String wrapWordsInPairs(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  final lines = <String>[];
  for (var index = 0; index < words.length; index += 2) {
    lines.add(
      index + 1 < words.length
          ? '${words[index]} ${words[index + 1]}'
          : words[index],
    );
  }
  return lines.join('\n');
}
