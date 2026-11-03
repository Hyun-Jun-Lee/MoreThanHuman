class WeeklyTopic {
  const WeeklyTopic({required this.id, required this.text});

  factory WeeklyTopic.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['text'] is! String) {
      throw const FormatException('Weekly topic is invalid.');
    }
    return WeeklyTopic(
      id: value['id'] as String,
      text: value['text'] as String,
    );
  }

  final String id;
  final String text;

  Map<String, String> toJson() => <String, String>{'id': id, 'text': text};
}

class WeeklyTopics {
  const WeeklyTopics({required this.weekStart, required this.topics});

  factory WeeklyTopics.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['topics'] is! List) {
      throw const FormatException('Weekly topics response is invalid.');
    }
    final Object? weekStart = value['week_start'];
    if (weekStart != null && weekStart is! String) {
      throw const FormatException('Weekly topic week is invalid.');
    }
    return WeeklyTopics(
      weekStart: weekStart as String?,
      topics: (value['topics'] as List)
          .map(WeeklyTopic.fromJson)
          .toList(growable: false),
    );
  }

  final String? weekStart;
  final List<WeeklyTopic> topics;

  Map<String, Object?> toJson() => <String, Object?>{
    'week_start': weekStart,
    'topics': topics.map((topic) => topic.toJson()).toList(growable: false),
  };
}
