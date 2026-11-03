import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/data/weekly_topic_cache.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly topic cache isolates users and language pairs', () async {
    final backend = _MemoryStorage();
    final cache = WeeklyTopicCache(backend);
    const published = WeeklyTopics(
      weekStart: '2026-09-28',
      topics: [WeeklyTopic(id: 'topic-1', text: '오늘의 취미 이야기')],
    );
    await cache.write('user-1', 'ko-en', published);
    expect((await cache.read('user-1', 'ko-en'))?.topics.single.id, 'topic-1');
    expect(await cache.read('user-2', 'ko-en'), isNull);
    expect(await cache.read('user-1', 'en-ko'), isNull);
  });
}

class _MemoryStorage implements SecureStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
