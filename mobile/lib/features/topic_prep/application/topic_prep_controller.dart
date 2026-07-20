import 'package:curitalk/features/topic_prep/data/api_topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopicPrepController extends AsyncNotifier<TopicPrepResult> {
  TopicPrepController(this.topic);

  final String topic;

  @override
  Future<TopicPrepResult> build() {
    return ref.watch(topicPrepRepositoryProvider).prepareTopic(topic);
  }

  Future<void> reload() async {
    state = const AsyncLoading<TopicPrepResult>();
    state = await AsyncValue.guard(() {
      return ref.read(topicPrepRepositoryProvider).prepareTopic(topic);
    });
  }
}

final topicPrepControllerProvider =
    AsyncNotifierProvider.family<TopicPrepController, TopicPrepResult, String>(
      TopicPrepController.new,
    );
