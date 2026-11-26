import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';

class MemoryBasketResetRepository implements SnackBasketResetRepository {
  SnackBasketReset value = const SnackBasketReset(language: 'en');
  bool fail = false;
  int calls = 0;
  Future<SnackBasketReset>? pending;

  @override
  Future<SnackBasketReset> read() async {
    calls++;
    if (fail) throw StateError('offline');
    if (pending != null) return pending!;
    return value;
  }
}

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
  'payload': type == 'idiomatic_expression'
      ? {
          'expression': 'break the ice',
          'literal_meaning': '얼음을 깨다',
          'meaning': '어색함을 풀다',
          'usage': '처음 만났을 때 사용해요.',
          'example': 'We played a game to break the ice.',
        }
      : {
          if (type == 'register_contrast') 'situation': '도움을 요청할 때',
          if (type == 'collocation') 'headword': 'word',
          if (type == 'regional_variant') 'meaning': '같은 뜻을 가진 표현이에요.',
          'items': List.generate(
            2,
            (i) => {
              'expression': 'word-$index-$i',
              if (type == 'regional_variant' || type == 'register_contrast')
                'label': i == 0 ? 'UK' : 'US',
              if (type == 'usage_contrast' || type == 'register_contrast')
                'usage': '편하게 대화할 때 사용하는 표현이에요. ' * (long ? 4 : 1),
              if (type == 'homonym' || type == 'collocation')
                'meaning': '다른 뜻을 가진 표현이에요. ' * (long ? 4 : 1),
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
