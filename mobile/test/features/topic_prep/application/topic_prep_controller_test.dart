import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller loads and reloads topic prep results', () async {
    final _FakeTopicPrepRepository repository = _FakeTopicPrepRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [topicPrepRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final TopicPrepResult result = await container.read(
      topicPrepControllerProvider('최근 롯데 경기').future,
    );
    await container
        .read(topicPrepControllerProvider('최근 롯데 경기').notifier)
        .reload();
    final TopicPrepResult reloaded = container
        .read(topicPrepControllerProvider('최근 롯데 경기'))
        .value!;

    expect(result.ready, isTrue);
    expect(reloaded.card?.summary, 'Prepared result 2');
    expect(repository.topics, <String>['최근 롯데 경기', '최근 롯데 경기']);
  });
}

class _FakeTopicPrepRepository implements TopicPrepRepository {
  final List<String> topics = <String>[];

  @override
  Future<TopicPrepResult> prepareTopic(String topic) async {
    topics.add(topic);
    return TopicPrepResult(
      ready: true,
      card: TopicPrepCard(
        topic: topic,
        summary: 'Prepared result ${topics.length}',
        directions: <TopicPrepDirection>[
          _direction(TopicPrepDirectionType.casualChat),
          _direction(TopicPrepDirectionType.debate),
          _direction(TopicPrepDirectionType.interviewQa),
          _direction(TopicPrepDirectionType.explanationPractice),
        ],
        sources: const <SearchSource>[],
        quality: _quality,
        timestamp: DateTime.utc(2026, 7, 2),
      ),
      quality: _quality,
      exampleTopics: const <String>[],
    );
  }
}

TopicPrepDirection _direction(TopicPrepDirectionType direction) {
  return TopicPrepDirection(
    direction: direction,
    title: direction.value,
    description: 'Description',
    firstQuestions: const <String>[
      'Question one?',
      'Question two?',
      'Question three?',
    ],
  );
}

const TopicPrepQuality _quality = TopicPrepQuality(
  isSufficient: true,
  sourceCount: 3,
  hasEnoughSources: true,
  relevance: true,
  freshness: true,
  specificity: true,
);
