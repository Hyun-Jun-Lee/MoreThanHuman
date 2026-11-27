import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/data/api_weekly_topic_repository.dart';
import 'package:curitalk/features/home/data/weekly_topic_cache.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyTopicsController extends AsyncNotifier<WeeklyTopics> {
  @override
  Future<WeeklyTopics> build() async {
    final user = ref.watch(authControllerProvider).value?.user;
    if (user == null) {
      return const WeeklyTopics(weekStart: null, topics: []);
    }
    final pair =
        '${user.language.nativeLanguage.code}-${user.language.targetLanguage.code}';
    final cache = ref.watch(weeklyTopicCacheProvider);
    try {
      final topics = await ref.watch(weeklyTopicRepositoryProvider).list();
      if (!_scopeMatches(user.id, pair)) {
        return const WeeklyTopics(weekStart: null, topics: []);
      }
      if (topics.topics.isNotEmpty) {
        try {
          await cache.write(user.id, pair, topics);
        } on Object {
          // 캐시 오류가 정상 응답을 가리지 않아요.
        }
      }
      return topics;
    } on Object {
      try {
        if (!_scopeMatches(user.id, pair)) {
          return const WeeklyTopics(weekStart: null, topics: []);
        }
        final cached = await cache.read(user.id, pair);
        return _scopeMatches(user.id, pair)
            ? (cached ?? const WeeklyTopics(weekStart: null, topics: []))
            : const WeeklyTopics(weekStart: null, topics: []);
      } on Object {
        return const WeeklyTopics(weekStart: null, topics: []);
      }
    }
  }

  bool _scopeMatches(String userId, String pair) {
    if (!ref.mounted) return false;
    final current = ref.read(authControllerProvider).value?.user;
    return current?.id == userId &&
        '${current?.language.nativeLanguage.code}-${current?.language.targetLanguage.code}' ==
            pair;
  }

  void refresh() {
    if (!state.isLoading) {
      ref.invalidateSelf();
    }
  }
}

final AsyncNotifierProvider<WeeklyTopicsController, WeeklyTopics>
weeklyTopicsControllerProvider =
    AsyncNotifierProvider<WeeklyTopicsController, WeeklyTopics>(
      WeeklyTopicsController.new,
    );
