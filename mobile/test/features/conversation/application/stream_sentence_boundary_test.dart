import 'package:curitalk/features/conversation/application/stream_sentence_boundary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'matches normalized TTS sentences to raw text without exposing a later one',
    () {
      const raw = 'Hello\n  world.  Again?';
      final first = streamSentenceEnd(raw, 'Hello world.', 0);
      expect(raw.substring(0, first), 'Hello\n  world.');
      final second = streamSentenceEnd(raw, 'Again?', first!);
      expect(raw.substring(0, second), raw);
      expect(streamSentenceEnd(raw, 'Missing.', first), isNull);
    },
  );
}
