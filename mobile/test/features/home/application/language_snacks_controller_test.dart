import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/domain/language_snack_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
