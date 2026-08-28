import 'package:curitalk/features/language/language.dart';

enum TopicPrepDirectionType {
  casualChat('CASUAL_CHAT'),
  debate('DEBATE'),
  explanationPractice('EXPLANATION_PRACTICE');

  const TopicPrepDirectionType(this.value);

  final String value;

  static TopicPrepDirectionType fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('Topic prep direction is invalid.');
    }
    return TopicPrepDirectionType.values.firstWhere(
      (TopicPrepDirectionType direction) => direction.value == value,
      orElse: () {
        throw const FormatException('Topic prep direction is invalid.');
      },
    );
  }
}

class SearchSource {
  const SearchSource({
    required this.title,
    required this.url,
    required this.snippet,
  });

  factory SearchSource.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Search source must be a JSON object.');
    }
    final Object? title = json['title'];
    final Object? url = json['url'];
    final Object? snippet = json['snippet'];
    if (title is! String ||
        title.trim().isEmpty ||
        url is! String ||
        url.trim().isEmpty ||
        snippet is! String) {
      throw const FormatException('Search source payload is invalid.');
    }
    return SearchSource(
      title: title.trim(),
      url: url.trim(),
      snippet: snippet.trim(),
    );
  }

  final String title;
  final String url;
  final String snippet;
}

class TopicPrepQuality {
  const TopicPrepQuality({
    required this.isSufficient,
    required this.sourceCount,
    required this.hasEnoughSources,
    required this.relevance,
    required this.freshness,
    required this.specificity,
    this.reason,
    this.retrySuggestion,
  });

  factory TopicPrepQuality.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Topic prep quality must be a JSON object.');
    }
    final Object? isSufficient = json['is_sufficient'];
    final Object? sourceCount = json['source_count'];
    final Object? hasEnoughSources = json['has_enough_sources'];
    final Object? relevance = json['relevance'];
    final Object? freshness = json['freshness'];
    final Object? specificity = json['specificity'];
    final Object? reason = json['reason'];
    final Object? retrySuggestion = json['retry_suggestion'];
    if (isSufficient is! bool ||
        sourceCount is! int ||
        sourceCount < 0 ||
        hasEnoughSources is! bool ||
        relevance is! bool ||
        freshness is! bool ||
        specificity is! bool ||
        (reason != null && reason is! String) ||
        (retrySuggestion != null && retrySuggestion is! String)) {
      throw const FormatException('Topic prep quality payload is invalid.');
    }
    return TopicPrepQuality(
      isSufficient: isSufficient,
      sourceCount: sourceCount,
      hasEnoughSources: hasEnoughSources,
      relevance: relevance,
      freshness: freshness,
      specificity: specificity,
      reason: reason as String?,
      retrySuggestion: retrySuggestion as String?,
    );
  }

  final bool isSufficient;
  final int sourceCount;
  final bool hasEnoughSources;
  final bool relevance;
  final bool freshness;
  final bool specificity;
  final String? reason;
  final String? retrySuggestion;
}

class TopicPrepDirection {
  const TopicPrepDirection({
    required this.direction,
    required this.title,
    required this.description,
    required this.firstQuestions,
  });

  factory TopicPrepDirection.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Topic prep direction must be a JSON object.',
      );
    }
    final Object? title = json['title'];
    final Object? description = json['description'];
    final Object? questions = json['first_questions'];
    if (title is! String ||
        title.trim().isEmpty ||
        description is! String ||
        description.trim().isEmpty ||
        questions is! List ||
        questions.length != 3 ||
        questions.any((Object? question) {
          return question is! String || question.trim().isEmpty;
        })) {
      throw const FormatException('Topic prep direction payload is invalid.');
    }
    return TopicPrepDirection(
      direction: TopicPrepDirectionType.fromJson(json['direction']),
      title: title.trim(),
      description: description.trim(),
      firstQuestions: questions
          .cast<String>()
          .map((String question) => question.trim())
          .toList(growable: false),
    );
  }

  final TopicPrepDirectionType direction;
  final String title;
  final String description;
  final List<String> firstQuestions;
}

class TopicPrepCard {
  const TopicPrepCard({
    required this.topic,
    required this.summary,
    required this.directions,
    required this.sources,
    required this.quality,
    required this.timestamp,
  });

  factory TopicPrepCard.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Topic prep card must be a JSON object.');
    }
    final Object? topic = json['topic'];
    final Object? summary = json['summary'];
    final Object? directions = json['directions'];
    final Object? sources = json['sources'];
    final DateTime? timestamp = DateTime.tryParse('${json['timestamp']}');
    if (topic is! String ||
        topic.trim().isEmpty ||
        summary is! String ||
        summary.trim().isEmpty ||
        directions is! List ||
        directions.length != 3 ||
        sources is! List ||
        timestamp == null) {
      throw const FormatException('Topic prep card payload is invalid.');
    }
    return TopicPrepCard(
      topic: topic.trim(),
      summary: summary.trim(),
      directions: directions
          .map(TopicPrepDirection.fromJson)
          .toList(growable: false),
      sources: sources.map(SearchSource.fromJson).toList(growable: false),
      quality: TopicPrepQuality.fromJson(json['quality']),
      timestamp: timestamp,
    );
  }

  final String topic;
  final String summary;
  final List<TopicPrepDirection> directions;
  final List<SearchSource> sources;
  final TopicPrepQuality quality;
  final DateTime timestamp;
}

class CustomFocusQuestions {
  const CustomFocusQuestions({
    required this.ready,
    required this.customFocus,
    required this.firstQuestions,
    this.retryGuidance,
  });

  factory CustomFocusQuestions.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Custom focus questions must be an object.');
    }
    final Object? ready = json['ready'];
    final Object? customFocus = json['custom_focus'];
    final Object? questions = json['first_questions'];
    final Object? retryGuidance = json['retry_guidance'];
    if (ready is! bool ||
        customFocus is! String ||
        customFocus.trim().isEmpty ||
        questions is! List ||
        (retryGuidance != null && retryGuidance is! String) ||
        (ready &&
            (questions.length != 3 ||
                questions.any(
                  (Object? value) => value is! String || value.trim().isEmpty,
                )))) {
      throw const FormatException('Custom focus questions payload is invalid.');
    }
    return CustomFocusQuestions(
      ready: ready,
      customFocus: customFocus.trim(),
      firstQuestions: questions
          .whereType<String>()
          .map((String question) => question.trim())
          .toList(growable: false),
      retryGuidance: retryGuidance as String?,
    );
  }

  final bool ready;
  final String customFocus;
  final List<String> firstQuestions;
  final String? retryGuidance;
}

class TopicPrepDirections {
  const TopicPrepDirections(this.directions);

  factory TopicPrepDirections.fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['directions'] is! List) {
      throw const FormatException('Topic prep directions payload is invalid.');
    }
    final List<TopicPrepDirection> directions = (json['directions'] as List)
        .map(TopicPrepDirection.fromJson)
        .toList(growable: false);
    if (directions.length != 3) {
      throw const FormatException('Topic prep directions count is invalid.');
    }
    return TopicPrepDirections(directions);
  }

  final List<TopicPrepDirection> directions;
}

class TopicPrepResult {
  const TopicPrepResult({
    required this.ready,
    required this.quality,
    required this.exampleTopics,
    this.language = LearningLanguageContext.defaultContext,
    this.card,
    this.retryGuidance,
  });

  factory TopicPrepResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Topic prep result must be a JSON object.');
    }
    final Object? ready = json['ready'];
    final Object? retryGuidance = json['retry_guidance'];
    final Object? exampleTopics = json['example_topics'];
    if (ready is! bool ||
        (retryGuidance != null && retryGuidance is! String) ||
        exampleTopics is! List ||
        exampleTopics.any((Object? topic) => topic is! String)) {
      throw const FormatException('Topic prep result payload is invalid.');
    }
    final TopicPrepCard? card = json['card'] == null
        ? null
        : TopicPrepCard.fromJson(json['card']);
    if (ready && card == null) {
      throw const FormatException('Ready topic prep result must include card.');
    }
    return TopicPrepResult(
      ready: ready,
      card: card,
      quality: TopicPrepQuality.fromJson(json['quality']),
      language: LearningLanguageContext.fromJson(json['language']),
      retryGuidance: retryGuidance as String?,
      exampleTopics: exampleTopics.cast<String>().toList(growable: false),
    );
  }

  final bool ready;
  final LearningLanguageContext language;
  final TopicPrepCard? card;
  final TopicPrepQuality quality;
  final String? retryGuidance;
  final List<String> exampleTopics;
}
