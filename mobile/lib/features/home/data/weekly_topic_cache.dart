import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyTopicCache {
  const WeeklyTopicCache(this.backend);

  final SecureStorageBackend backend;

  String _key(String userId, String pair) =>
      'curitalk.weekly_topics.v1.$userId.$pair';

  Future<WeeklyTopics?> read(String userId, String pair) async {
    final key = _key(userId, pair);
    final encoded = await backend.read(key);
    if (encoded == null) return null;
    try {
      return WeeklyTopics.fromJson(jsonDecode(encoded));
    } on Object {
      await backend.delete(key);
      return null;
    }
  }

  Future<void> write(String userId, String pair, WeeklyTopics topics) async {
    await backend.write(_key(userId, pair), jsonEncode(topics.toJson()));
  }
}

final Provider<WeeklyTopicCache> weeklyTopicCacheProvider =
    Provider<WeeklyTopicCache>(
      (ref) => WeeklyTopicCache(ref.watch(secureStorageBackendProvider)),
    );
