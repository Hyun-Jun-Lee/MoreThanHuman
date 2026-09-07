import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      backend.values[SecureLanguageSnackCache.storageKey] = jsonEncode(
        <Object?>[
          <String, dynamic>{'id': 'only-an-id'},
        ],
      );

      expect(await cache.read(), isNull);
      expect(
        backend.values.containsKey(SecureLanguageSnackCache.storageKey),
        isFalse,
      );
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
  'category': 'Vocabulary',
  'left_label': 'British English',
  'left_word': leftWord,
  'right_label': 'American English',
  'right_word': 'chips',
  'meaning': '둘 다 감자칩을 뜻해요.',
  'example': 'Would you like a bag of crisps?',
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
