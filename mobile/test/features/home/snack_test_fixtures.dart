import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';

LanguageSnack testSnack(
  int index, {
  String language = 'en',
  String type = 'regional_variant',
  bool long = false,
}) => LanguageSnack.fromJson({
  'id': '$language-$index',
  'content_type': type,
  'schema_version': 1,
  'content_language': language,
  'explanation_language': language == 'en' ? 'ko' : 'en',
  'payload': {
    if (type == 'regional_variant') 'meaning': '같은 뜻을 가진 표현이에요.',
    'items': List.generate(
      2,
      (i) => {
        'expression': 'word-$index-$i',
        if (type == 'regional_variant') 'label': i == 0 ? 'UK' : 'US',
        if (type == 'usage_contrast')
          'usage': '편하게 대화할 때 사용하는 표현이에요. ' * (long ? 4 : 1),
        if (type == 'homonym') 'meaning': '다른 뜻을 가진 표현이에요. ' * (long ? 4 : 1),
        if (type != 'regional_variant')
          'example': 'This is an example sentence. ' * (long ? 6 : 1),
        if (type != 'regional_variant')
          'example_translation': '표현을 사용하는 예문이에요. ' * (long ? 6 : 1),
      },
    ),
  },
  'published_at': '2026-09-18T00:00:00Z',
  'created_at': '2026-09-18T00:00:00Z',
  'updated_at': '2026-09-18T00:00:00Z',
});

class MemorySnackStorage implements SecureStorageBackend {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async {
    if (fail) throw StateError('unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}
