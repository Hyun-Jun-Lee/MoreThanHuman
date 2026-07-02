import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';

abstract interface class TopicPrepRepository {
  Future<TopicPrepResult> prepareTopic(String topic);
}
