import 'dart:async';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/domain/language_snack_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'switching language ignores a late previous-language response',
    () async {
      var language = 'en';
      final repository = _DeferredRepository();
      final cache = _FakeLanguageSnackCache();
      final container = ProviderContainer(
        overrides: [
          languageSnacksEnabledProvider.overrideWithValue(true),
          languageSnackLanguageProvider.overrideWith((ref) => language),
          languageSnackRepositoryProvider.overrideWithValue(repository),
          languageSnackCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        languageSnacksControllerProvider,
        (_, next) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      language = 'ko';
      container.invalidate(languageSnackLanguageProvider);
      await Future<void>.delayed(Duration.zero);
      final korean = LanguageSnack.fromJson(
        _snackJson('배')
          ..['content_language'] = 'ko'
          ..['explanation_language'] = 'en',
      );
      repository.requests[1].complete([korean]);
      expect(await container.read(languageSnacksControllerProvider.future), [
        korean,
      ]);
      repository.requests[0].complete([_snack]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(languageSnacksControllerProvider).value, [korean]);
      expect(cache.written, [korean]);
      expect(cache.writeCount, 1);
    },
  );

  test(
    'authenticated controller fetches snacks and replaces the cache',
    () async {
      final _FakeLanguageSnackRepository repository =
          _FakeLanguageSnackRepository(snacks: <LanguageSnack>[_snack]);
      final _FakeLanguageSnackCache cache = _FakeLanguageSnackCache();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          languageSnacksEnabledProvider.overrideWithValue(true),
          languageSnackRepositoryProvider.overrideWithValue(repository),
          languageSnackCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      final List<LanguageSnack> snacks = await container.read(
        languageSnacksControllerProvider.future,
      );

      expect(snacks, <LanguageSnack>[_snack]);
      expect(repository.callCount, 1);
      expect(cache.written, <LanguageSnack>[_snack]);
    },
  );

  test(
    'controller falls back to the last successful cache after an API failure',
    () async {
      final _FakeLanguageSnackRepository repository =
          _FakeLanguageSnackRepository(error: StateError('offline'));
      final _FakeLanguageSnackCache cache = _FakeLanguageSnackCache(
        stored: <LanguageSnack>[_cachedSnack],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          languageSnacksEnabledProvider.overrideWithValue(true),
          languageSnackRepositoryProvider.overrideWithValue(repository),
          languageSnackCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      final List<LanguageSnack> snacks = await container.read(
        languageSnacksControllerProvider.future,
      );

      expect(snacks, <LanguageSnack>[_cachedSnack]);
      expect(cache.writeCount, 0);
    },
  );

  test(
    'controller hides only the snack area when API and cache both fail',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          languageSnacksEnabledProvider.overrideWithValue(true),
          languageSnackRepositoryProvider.overrideWithValue(
            _FakeLanguageSnackRepository(error: StateError('offline')),
          ),
          languageSnackCacheProvider.overrideWithValue(
            _FakeLanguageSnackCache(readError: StateError('unavailable')),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<LanguageSnack> snacks = await container.read(
        languageSnacksControllerProvider.future,
      );

      expect(snacks, isEmpty);
    },
  );

  test('unauthenticated controller does not request snacks', () async {
    final _FakeLanguageSnackRepository repository =
        _FakeLanguageSnackRepository(snacks: <LanguageSnack>[_snack]);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        languageSnacksEnabledProvider.overrideWithValue(false),
        languageSnackRepositoryProvider.overrideWithValue(repository),
        languageSnackCacheProvider.overrideWithValue(_FakeLanguageSnackCache()),
      ],
    );
    addTearDown(container.dispose);

    final List<LanguageSnack> snacks = await container.read(
      languageSnacksControllerProvider.future,
    );

    expect(snacks, isEmpty);
    expect(repository.callCount, 0);
  });
}

class _FakeLanguageSnackRepository implements LanguageSnackRepository {
  _FakeLanguageSnackRepository({
    this.snacks = const <LanguageSnack>[],
    this.error,
  });

  final List<LanguageSnack> snacks;
  final Object? error;
  int callCount = 0;

  @override
  Future<List<LanguageSnack>> listPublished() async {
    callCount += 1;
    if (error != null) throw error!;
    return snacks;
  }
}

class _DeferredRepository implements LanguageSnackRepository {
  final requests = <Completer<List<LanguageSnack>>>[];
  @override
  Future<List<LanguageSnack>> listPublished() {
    final request = Completer<List<LanguageSnack>>();
    requests.add(request);
    return request.future;
  }
}

class _FakeLanguageSnackCache implements LanguageSnackCache {
  _FakeLanguageSnackCache({this.stored, this.readError});

  final List<LanguageSnack>? stored;
  final Object? readError;
  List<LanguageSnack>? written;
  int writeCount = 0;

  @override
  Future<List<LanguageSnack>?> read() async {
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> write(List<LanguageSnack> snacks) async {
    writeCount += 1;
    written = snacks;
  }
}

final LanguageSnack _snack = LanguageSnack.fromJson(_snackJson('crisps'));
final LanguageSnack _cachedSnack = LanguageSnack.fromJson(_snackJson('flat'));

Map<String, dynamic> _snackJson(String leftWord) => <String, dynamic>{
  'id': '550e8400-e29b-41d4-a716-446655440000',
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
