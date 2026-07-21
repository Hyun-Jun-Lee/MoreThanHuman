enum LearningLanguageCode {
  ko('ko', 'Korean', '한국어', '韩语'),
  en('en', 'English', '영어', '英语'),
  zh('zh', 'Chinese', '중국어', '中文');

  const LearningLanguageCode(
    this.code,
    this.englishName,
    this.koreanName,
    this.chineseName,
  );

  final String code;
  final String englishName;
  final String koreanName;
  final String chineseName;

  static LearningLanguageCode fromCode(Object? value) {
    for (final LearningLanguageCode language in values) {
      if (language.code == value) {
        return language;
      }
    }
    throw FormatException('Unsupported language code: $value');
  }

  String displayName(String localeCode) {
    return switch (localeCode) {
      'ko' => koreanName,
      'zh' => chineseName,
      _ => englishName,
    };
  }
}

class LearningLanguageContext {
  const LearningLanguageContext({
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.feedbackLanguage,
  });

  factory LearningLanguageContext.fromJson(Object? json) {
    if (json == null) {
      return defaultContext;
    }
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Language context must be a JSON object.');
    }
    return LearningLanguageContext(
      nativeLanguage: LearningLanguageCode.fromCode(json['native_language']),
      targetLanguage: LearningLanguageCode.fromCode(json['target_language']),
      feedbackLanguage: LearningLanguageCode.fromCode(
        json['feedback_language'] ?? json['native_language'],
      ),
    );
  }

  factory LearningLanguageContext.fromStorageValue(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return defaultContext;
    }
    final List<String> parts = normalized.split('|');
    if (parts.length != 3) {
      throw const FormatException('Language context storage value is invalid.');
    }
    return LearningLanguageContext(
      nativeLanguage: LearningLanguageCode.fromCode(parts[0]),
      targetLanguage: LearningLanguageCode.fromCode(parts[1]),
      feedbackLanguage: LearningLanguageCode.fromCode(parts[2]),
    );
  }

  static const LearningLanguageContext defaultContext = LearningLanguageContext(
    nativeLanguage: LearningLanguageCode.ko,
    targetLanguage: LearningLanguageCode.en,
    feedbackLanguage: LearningLanguageCode.ko,
  );

  static const List<LearningLanguageContext> supportedContexts =
      <LearningLanguageContext>[
        LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.ko,
          targetLanguage: LearningLanguageCode.en,
          feedbackLanguage: LearningLanguageCode.ko,
        ),
        LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.en,
          targetLanguage: LearningLanguageCode.ko,
          feedbackLanguage: LearningLanguageCode.en,
        ),
        LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.zh,
          targetLanguage: LearningLanguageCode.en,
          feedbackLanguage: LearningLanguageCode.zh,
        ),
        LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.zh,
          targetLanguage: LearningLanguageCode.ko,
          feedbackLanguage: LearningLanguageCode.zh,
        ),
      ];

  final LearningLanguageCode nativeLanguage;
  final LearningLanguageCode targetLanguage;
  final LearningLanguageCode feedbackLanguage;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'native_language': nativeLanguage.code,
      'target_language': targetLanguage.code,
      'feedback_language': feedbackLanguage.code,
    };
  }

  String toStorageValue() {
    return '${nativeLanguage.code}|${targetLanguage.code}|${feedbackLanguage.code}';
  }

  String pairLabel(String localeCode) {
    return '${nativeLanguage.displayName(localeCode)} -> ${targetLanguage.displayName(localeCode)}';
  }

  String helperText(String localeCode) {
    final String target = targetLanguage.displayName(localeCode);
    final String feedback = feedbackLanguage.displayName(localeCode);
    return switch (localeCode) {
      'ko' => '대화: $target · 피드백: $feedback',
      'zh' => '对话：$target · 反馈：$feedback',
      _ => 'Conversation: $target · Feedback: $feedback',
    };
  }

  String firstAnswerHint(String localeCode) {
    final String target = targetLanguage.displayName(localeCode);
    return switch (localeCode) {
      'ko' => '$target로 첫 답변을 입력하세요...',
      'zh' => '请用$target输入你的第一句回答...',
      _ => 'Type your first answer in $target...',
    };
  }

  String firstAnswerSemanticLabel(String localeCode) {
    final String target = targetLanguage.displayName(localeCode);
    return switch (localeCode) {
      'ko' => '$target 첫 답변',
      'zh' => '$target第一句回答',
      _ => 'First answer in $target',
    };
  }

  LearningLanguageContext copyWith({
    LearningLanguageCode? nativeLanguage,
    LearningLanguageCode? targetLanguage,
    LearningLanguageCode? feedbackLanguage,
  }) {
    return LearningLanguageContext(
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      feedbackLanguage: feedbackLanguage ?? this.feedbackLanguage,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LearningLanguageContext &&
        other.nativeLanguage == nativeLanguage &&
        other.targetLanguage == targetLanguage &&
        other.feedbackLanguage == feedbackLanguage;
  }

  @override
  int get hashCode =>
      Object.hash(nativeLanguage, targetLanguage, feedbackLanguage);
}

LearningLanguageContext defaultLanguageContextForLocale(String localeCode) {
  return switch (localeCode) {
    'en' => const LearningLanguageContext(
      nativeLanguage: LearningLanguageCode.en,
      targetLanguage: LearningLanguageCode.ko,
      feedbackLanguage: LearningLanguageCode.en,
    ),
    'zh' => const LearningLanguageContext(
      nativeLanguage: LearningLanguageCode.zh,
      targetLanguage: LearningLanguageCode.ko,
      feedbackLanguage: LearningLanguageCode.zh,
    ),
    _ => LearningLanguageContext.defaultContext,
  };
}
