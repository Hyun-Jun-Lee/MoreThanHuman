import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';

abstract interface class TopicPrepRepository {
  Future<TopicPrepResult> prepareTopic(String topic);
}

class TopicPrepStreamEvent {
  const TopicPrepStreamEvent.summary(this.summary) : result = null;
  const TopicPrepStreamEvent.card(this.result) : summary = null;

  final String? summary;
  final TopicPrepResult? result;
}

abstract interface class TopicPrepStreamRepository {
  Stream<TopicPrepStreamEvent> prepareTopicStream(String topic);
}

abstract interface class TopicPrepCustomFocusRepository {
  Future<CustomFocusQuestions> prepareCustomFocusQuestions({
    required String topic,
    required String customFocus,
  });

  Future<TopicPrepDirections> regenerateDirections({
    required String topic,
    required List<String> previousDirections,
  });
}
