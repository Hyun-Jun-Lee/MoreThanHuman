import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiWeeklyTopicRepository {
  const ApiWeeklyTopicRepository(this.client);

  final ApiClient client;

  Future<WeeklyTopics> list() async {
    final response = await client.get<WeeklyTopics>(
      'conversation-topics/weekly/',
      decodeData: WeeklyTopics.fromJson,
    );
    return response.data;
  }
}

final Provider<ApiWeeklyTopicRepository> weeklyTopicRepositoryProvider =
    Provider<ApiWeeklyTopicRepository>(
      (ref) => ApiWeeklyTopicRepository(ref.watch(apiClientProvider)),
    );
