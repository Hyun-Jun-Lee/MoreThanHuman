import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a complete published language snack', () {
    final LanguageSnack snack = LanguageSnack.fromJson(_snackJson());

    expect(snack.id, '550e8400-e29b-41d4-a716-446655440000');
    expect(snack.leftWord, 'crisps');
    expect(snack.rightWord, 'chips');
    expect(snack.publishedAt, DateTime.utc(2026, 9, 6, 12));
  });

  test('rejects a missing required string or invalid published timestamp', () {
    expect(
      () => LanguageSnack.fromJson(_snackJson()..remove('meaning')),
      throwsFormatException,
    );
    expect(
      () => LanguageSnack.fromJson(_snackJson()..['published_at'] = 'tomorrow'),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _snackJson() => <String, dynamic>{
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'category': 'Vocabulary',
  'left_label': 'British English',
  'left_word': 'crisps',
  'right_label': 'American English',
  'right_word': 'chips',
  'meaning': '둘 다 감자칩을 뜻해요.',
  'example': 'Would you like a bag of crisps?',
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
