import 'package:curitalk/features/topic_prep/data/api_topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopicPrepController extends AsyncNotifier<TopicPrepResult> {
  TopicPrepController(this.topic);

  final String topic;

  @override
  Future<TopicPrepResult> build() async {
    final TopicPrepRepository repository = ref.watch(
      topicPrepRepositoryProvider,
    );
    if (repository is! TopicPrepStreamRepository) {
      return repository.prepareTopic(topic);
    }
    TopicPrepResult? result;
    await for (final TopicPrepStreamEvent event
        in (repository as TopicPrepStreamRepository).prepareTopicStream(
          topic,
        )) {
      if (event.summary case final String summary) {
        ref.read(topicPrepSummaryProvider(topic).notifier).setSummary(summary);
      }
      if (event.result case final TopicPrepResult complete) {
        result = complete;
      }
    }
    if (result == null) {
      throw const FormatException('Topic prep stream did not return a card.');
    }
    return result;
  }

  Future<void> reload() async {
    ref.read(topicPrepSummaryProvider(topic).notifier).setSummary(null);
    state = const AsyncLoading<TopicPrepResult>();
    state = await AsyncValue.guard(build);
  }
}

class TopicPrepSummaryController extends Notifier<String?> {
  TopicPrepSummaryController(this.topic);

  final String topic;

  @override
  String? build() => null;

  void setSummary(String? summary) => state = summary;
}

final topicPrepSummaryProvider =
    NotifierProvider.family<TopicPrepSummaryController, String?, String>(
      TopicPrepSummaryController.new,
    );

final topicPrepControllerProvider =
    AsyncNotifierProvider.family<TopicPrepController, TopicPrepResult, String>(
      TopicPrepController.new,
    );
