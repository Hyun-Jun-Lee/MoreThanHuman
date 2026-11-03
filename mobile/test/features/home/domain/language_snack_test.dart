import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in ['usage_contrast', 'homonym']) {
    test('$type preserves expression-level explanations and examples', () {
      final json = _snackJson()
        ..['content_type'] = type
        ..['content_language'] = 'ko'
        ..['explanation_language'] = 'en'
        ..['payload'] = {
          'items': List.generate(
            2,
            (i) => {
              'expression': '배',
              type == 'homonym' ? 'meaning' : 'usage': 'Explanation $i',
              'example': '배를 먹어요.',
              'example_translation': 'I eat a pear.',
            },
          ),
        };
      final snack = LanguageSnack.fromJson(json);
      expect(snack.items.length, 2);
      expect(snack.items.first.exampleTranslation, 'I eat a pear.');
      expect(LanguageSnack.fromJson(snack.toJson()).toJson(), snack.toJson());
      expect(snack.contentLanguage, 'ko');
    });
  }

  test('unknown types and schema versions are recognized as unsupported', () {
    expect(
      LanguageSnack.isSupported(_snackJson()..['content_type'] = 'future'),
      isFalse,
    );
    expect(
      LanguageSnack.isSupported(_snackJson()..['schema_version'] = 2),
      isFalse,
    );
  });

  test('parses a complete published language snack', () {
    final LanguageSnack snack = LanguageSnack.fromJson(_snackJson());

    expect(snack.id, '550e8400-e29b-41d4-a716-446655440000');
    expect(snack.items[0].expression, 'crisps');
    expect(snack.items[1].expression, 'chips');
    expect(snack.publishedAt, DateTime.utc(2026, 9, 6, 12));
  });

  test('rejects a missing required string or invalid published timestamp', () {
    expect(
      () => LanguageSnack.fromJson(_snackJson()..remove('payload')),
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
  'content_type': 'regional_variant',
  'schema_version': 1,
  'content_language': 'en',
  'explanation_language': 'ko',
  'payload': {
    'meaning': '둘 다 감자칩을 뜻해요.',
    'items': [
      {'label': 'British English', 'expression': 'crisps'},
      {'label': 'American English', 'expression': 'chips'},
    ],
  },
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
