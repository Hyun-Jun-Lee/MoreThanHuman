import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('language caches remain isolated and legacy data is removed', () async {
    final backend = _MemorySecureStorage();
    final english = SecureLanguageSnackCache(backend);
    final korean = SecureLanguageSnackCache(backend, contentLanguage: 'ko');
    final en = LanguageSnack.fromJson(
      _snackJson(id: 'english', leftWord: 'crisps'),
    );
    final ko = LanguageSnack.fromJson(
      _snackJson(id: 'korean', leftWord: '감자')
        ..['content_language'] = 'ko'
        ..['explanation_language'] = 'en',
    );
    backend.values[SecureLanguageSnackCache.legacyKey] = 'old';
    await english.write([en]);
    await korean.write([ko]);
    expect((await english.read())!.single.id, 'english');
    expect((await korean.read())!.single.id, 'korean');
    expect(
      backend.values.containsKey(SecureLanguageSnackCache.legacyKey),
      isFalse,
    );
    await expectLater(korean.write([en]), throwsFormatException);
  });

  test('cache restores the same validated snack order it saved', () async {
    final _MemorySecureStorage backend = _MemorySecureStorage();
    final SecureLanguageSnackCache cache = SecureLanguageSnackCache(backend);
    final List<LanguageSnack> snacks = <LanguageSnack>[
      LanguageSnack.fromJson(_snackJson(id: 'first', leftWord: 'crisps')),
      LanguageSnack.fromJson(_snackJson(id: 'second', leftWord: 'flat')),
    ];

    await cache.write(snacks);
    final List<LanguageSnack>? restored = await cache.read();

    expect(restored?.map((LanguageSnack snack) => snack.id), <String>[
      'first',
      'second',
    ]);
  });

  test(
    'cache clears corrupted or partial payloads instead of surfacing an error',
    () async {
      final _MemorySecureStorage backend = _MemorySecureStorage();
      final SecureLanguageSnackCache cache = SecureLanguageSnackCache(backend);
      backend.values[cache.storageKey] = jsonEncode(<Object?>[
        <String, dynamic>{'id': 'only-an-id'},
      ]);

      expect(await cache.read(), isNull);
      expect(backend.values.containsKey(cache.storageKey), isFalse);
    },
  );
}

class _MemorySecureStorage implements SecureStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

Map<String, dynamic> _snackJson({
  required String id,
  required String leftWord,
}) => <String, dynamic>{
  'id': id,
  'content_type': 'regional_variant',
  'schema_version': 1,
  'content_language': 'en',
  'explanation_language': 'ko',
  'payload': {
    'meaning': '둘 다 감자칩을 뜻해요.',
    'items': [
      {'label': 'British English', 'expression': leftWord},
      {'label': 'American English', 'expression': 'chips'},
    ],
  },
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
