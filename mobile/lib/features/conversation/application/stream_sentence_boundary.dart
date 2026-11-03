/// TTS 문장은 공백이 정규화되어 오므로 원본 생성 텍스트의 끝 위치를 찾아요.
int? streamSentenceEnd(String text, String sentence, int from) {
  if (sentence.isEmpty || from < 0 || from > text.length) return null;
  var source = from;
  var target = 0;
  final space = RegExp(r'\s');
  while (target < sentence.length) {
    if (space.hasMatch(sentence[target])) {
      if (source >= text.length || !space.hasMatch(text[source])) return null;
      while (target < sentence.length && space.hasMatch(sentence[target])) {
        target++;
      }
      while (source < text.length && space.hasMatch(text[source])) {
        source++;
      }
    } else {
      while (source < text.length && space.hasMatch(text[source])) {
        source++;
      }
      if (source >= text.length || text[source] != sentence[target]) {
        return null;
      }
      source++;
      target++;
    }
  }
  return source;
}

/// 새 문장의 첫 실제 글자 전까지 있는 공백의 끝 위치예요.
int streamSentenceLeadingSpaceEnd(String text, int from, int end) {
  final space = RegExp(r'\s');
  var index = from;
  while (index < end && space.hasMatch(text[index])) {
    index++;
  }
  return index;
}
