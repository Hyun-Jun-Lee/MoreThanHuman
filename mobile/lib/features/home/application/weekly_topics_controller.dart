import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/data/api_weekly_topic_repository.dart';
import 'package:curitalk/features/home/data/weekly_topic_cache.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeeklyTopicsController extends AsyncNotifier<WeeklyTopics> {
  String? _fetchedSlot;
  DateTime? _lastFetch;
  String? _scope;

  @override
  Future<WeeklyTopics> build() async {
    final user = ref.watch(authControllerProvider).value?.user;
    if (user == null) {
      _scope = null;
      _fetchedSlot = null;
      _lastFetch = null;
      return const WeeklyTopics(weekStart: null, topics: []);
    }
    final pair =
        '${user.language.nativeLanguage.code}-${user.language.targetLanguage.code}';
    final scope = '${user.id}.$pair';
    if (_scope != scope) {
      _scope = scope;
      _fetchedSlot = null;
      _lastFetch = null;
    }
    final cache = ref.watch(weeklyTopicCacheProvider);
    try {
      final topics = await ref.watch(weeklyTopicRepositoryProvider).list();
      if (!_scopeMatches(user.id, pair)) {
        return const WeeklyTopics(weekStart: null, topics: []);
      }
      _fetchedSlot = _currentSlot();
      _lastFetch = DateTime.now();
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

  void refreshIfNewWeek() {
    if (!state.isLoading &&
        (_fetchedSlot != _currentSlot() ||
            _lastFetch == null ||
            DateTime.now().difference(_lastFetch!) >=
                const Duration(minutes: 5))) {
      ref.invalidateSelf();
    }
  }

  String _currentSlot() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    var monday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    if (now.hour < 5 && now.weekday == DateTime.monday) {
      monday = monday.subtract(const Duration(days: 7));
    }
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}

final AsyncNotifierProvider<WeeklyTopicsController, WeeklyTopics>
weeklyTopicsControllerProvider =
    AsyncNotifierProvider<WeeklyTopicsController, WeeklyTopics>(
      WeeklyTopicsController.new,
    );
