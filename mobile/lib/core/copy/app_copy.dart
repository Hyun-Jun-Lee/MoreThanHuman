import 'package:flutter/material.dart';

class AppCopy {
  const AppCopy._(this.localeCode);

  factory AppCopy.forLocale(Locale locale) {
    return AppCopy._(resolveLocaleCode(locale));
  }

  factory AppCopy.of(BuildContext context) {
    return AppCopy.forLocale(Localizations.localeOf(context));
  }

  final String localeCode;

  bool get isKorean => localeCode == 'ko';

  static String resolveLocaleCode(Locale locale) {
    return locale.languageCode == 'ko' ? 'ko' : 'en';
  }

  String languageName(String code) {
    return switch ((localeCode, code)) {
      ('ko', 'en') => '영어',
      ('ko', 'ko') => '한국어',
      ('ko', 'zh') => '중국어',
      (_, 'en') => 'English',
      (_, 'ko') => 'Korean',
      (_, 'zh') => 'Chinese',
      _ => code,
    };
  }

  String languagePairDescription({
    required String nativeCode,
    required String targetCode,
    required String feedbackCode,
  }) {
    final String target = languageName(targetCode);
    final String feedback = languageName(feedbackCode);
    return isKorean
        ? '대화: $target · 피드백: $feedback'
        : 'Conversation: $target · Feedback: $feedback';
  }

  String languagePairLabel({
    required String nativeCode,
    required String targetCode,
  }) {
    return '${languageName(nativeCode)} -> ${languageName(targetCode)}';
  }

  String get comingSoonLabel => isKorean ? '준비 중' : 'Coming soon';

  String firstAnswerHint(String targetCode) {
    final String target = languageName(targetCode);
    return isKorean
        ? '$target로 첫 답변을 입력하세요...'
        : 'Type your first answer in $target...';
  }

  String firstAnswerSemanticLabel(String targetCode) {
    final String target = languageName(targetCode);
    return isKorean ? '$target 첫 답변' : 'First answer in $target';
  }

  String preferenceChangePolicyText() {
    return isKorean
        ? '새 대화부터 적용돼요. 기존 대화는 시작할 때 선택한 언어쌍을 유지해요.'
        : 'Applies to new conversations. Existing conversations keep the language pair they started with.';
  }

  AppOnboardingCopy get onboarding {
    return isKorean ? AppOnboardingCopy.korean : AppOnboardingCopy.english;
  }

  AppLoginCopy get login {
    return isKorean ? AppLoginCopy.korean : AppLoginCopy.english;
  }

  String loginFailureMessage(String reason) {
    return switch (reason) {
      'identity' =>
        isKorean
            ? 'Google 로그인을 완료할 수 없어요. 다시 시도해 주세요.'
            : 'Google sign-in could not be completed. Please try again.',
      'request' =>
        isKorean
            ? '로그인을 완료할 수 없어요. 다시 시도해 주세요.'
            : 'Sign-in could not be completed. Please try again.',
      _ =>
        isKorean
            ? '로그인을 완료할 수 없어요. 다시 시도해 주세요.'
            : 'Sign-in could not be completed. Please try again.',
    };
  }

  String failureMessage(String reason) {
    return switch (reason) {
      'textRequestFailed' =>
        isKorean
            ? '메시지를 보내지 못했어요. 다시 시도해 주세요.'
            : 'Your message could not be sent. Please try again.',
      'audioRequestFailed' =>
        isKorean
            ? '음성 메시지를 보내지 못했어요. 다시 시도해 주세요.'
            : 'Your voice message could not be sent. Please try again.',
      'freeChatRequestFailed' =>
        isKorean
            ? '대화를 시작하지 못했어요. 다시 시도해 주세요.'
            : 'The conversation could not be started. Please try again.',
      'roleplayRequestFailed' =>
        isKorean
            ? '역할극을 시작하지 못했어요. 다시 시도해 주세요.'
            : 'Roleplay could not be started. Please try again.',
      'grammarRequestFailed' =>
        isKorean
            ? '문법 피드백을 지금 불러오지 못했어요.'
            : 'Grammar feedback is unavailable right now.',
      'assistantAudioUnavailable' =>
        isKorean
            ? '응답 음성을 재생할 수 없어요. 텍스트로 계속 대화할 수 있어요.'
            : 'Audio for this response is unavailable. You can keep chatting with the text.',
      'permissionDenied' =>
        isKorean ? '마이크 권한이 필요해요.' : 'Microphone permission is required.',
      'emptyRecording' =>
        isKorean
            ? '음성이 인식되지 않았어요. 조금 더 크게 또는 길게 말해 주세요.'
            : 'We could not hear enough audio. Try speaking a little longer.',
      'startFailed' =>
        isKorean
            ? '녹음을 시작하지 못했어요. 다시 시도해 주세요.'
            : 'Recording could not be started. Please try again.',
      'stopFailed' =>
        isKorean
            ? '녹음을 마치지 못했어요. 다시 시도해 주세요.'
            : 'Recording could not be finished. Please try again.',
      'playbackFailed' =>
        isKorean
            ? '음성을 재생하지 못했어요. 다시 시도해 주세요.'
            : 'Audio could not be played. Please try again.',
      _ =>
        isKorean
            ? '지금은 완료하지 못했어요. 다시 시도해 주세요.'
            : 'This could not be completed right now. Please try again.',
    };
  }

  String voiceStatus(String phase) {
    return switch (phase) {
      'starting' => isKorean ? '녹음을 시작하는 중...' : 'Starting recording...',
      'recording' => isKorean ? '녹음 중...' : 'Recording...',
      'stopping' => isKorean ? '녹음을 마무리하는 중...' : 'Finishing recording...',
      'sending' => isKorean ? '음성 메시지를 보내는 중...' : 'Sending voice message...',
      'startingConversation' =>
        isKorean ? '음성으로 대화를 시작하는 중...' : 'Starting with your voice...',
      _ => '',
    };
  }

  String get retryLabel => isKorean ? '다시 시도' : 'Retry';
  String get backToHomeLabel => isKorean ? '홈으로 돌아가기' : 'Back to home';
  String get conversationTitle => isKorean ? '대화' : 'Conversation';
  String get deleteConversationTooltip =>
      isKorean ? '대화 삭제' : 'Delete conversation';
  String deleteConversationTitle(String title) =>
      isKorean ? '"$title" 대화를 삭제할까요?' : 'Delete "$title"?';
  String get deleteConversationMessage => isKorean
      ? '대화와 관련 메시지, 문법 피드백이 영구적으로 삭제돼요.'
      : 'This permanently deletes the conversation, its messages, and grammar feedback.';
  String get deleteLabel => isKorean ? '삭제' : 'Delete';
  String get deletingConversation =>
      isKorean ? '대화를 삭제하는 중...' : 'Deleting conversation...';
  String get deleteConversationFailed => isKorean
      ? '대화를 삭제하지 못했어요. 다시 시도해 주세요.'
      : 'Could not delete the conversation. Please try again.';
  String get loadingMessages =>
      isKorean ? '대화를 불러오는 중...' : 'Loading messages...';
  String get loadConversationFailedTitle =>
      isKorean ? '대화를 불러오지 못했어요.' : 'Could not load this conversation.';
  String get connectionRetryMessage => isKorean
      ? '연결을 확인하고 다시 시도해 주세요.'
      : 'Check your connection and try again.';
  String get noMessagesTitle => isKorean ? '아직 메시지가 없어요.' : 'No messages yet.';
  String get noMessagesMessage => isKorean
      ? '첫 답변을 보내며 대화를 시작해 보세요.'
      : 'Send your first reply to begin practicing.';
  String get grammarCheckingLabel =>
      isKorean ? '문법을 확인하는 중...' : 'Grammar: checking...';
  String get grammarDelayedLabel => isKorean
      ? '문법 피드백이 평소보다 오래 걸리고 있어요.'
      : 'Grammar feedback is taking longer than usual.';
  String get audioLoadingLabel => isKorean ? '음성 불러오는 중' : 'Loading audio';
  String get audioPlayingLabel => isKorean ? '응답 음성 재생 중' : 'Playing response';
  String get audioReplayLabel => isKorean ? '응답 음성 다시 듣기' : 'Replay response';
  String get stopAudioResponseLabel =>
      isKorean ? '음성 응답 중단' : 'Stop audio response';
  String get audioPlayLabel => isKorean ? '응답 음성 듣기' : 'Play response';
  String get customRoleplayInputTooShort =>
      isKorean ? '두 글자 이상 입력해 주세요.' : 'Enter at least 2 characters.';
  String get freeChatTitle => isKorean ? '자유 대화' : 'Free Chat';
  String get topicInputTitle =>
      isKorean ? '어떤 주제로 이야기하고 싶나요?' : 'What topic do you want to talk about?';
  String get topicInputDescription => isKorean
      ? '뉴스, 취미, 여행, 스포츠처럼 지금 마음이 가는 주제를 골라 보세요.'
      : 'Bring a news story, hobby, trip idea, sports result, or anything you actually care about.';
  String get conversationTopicLabel =>
      isKorean ? '대화 주제' : 'Conversation topic';
  String get examplesLabel => isKorean ? '예시' : 'Examples';
  String get prepareLabel => isKorean ? '준비하기' : 'PREPARE';
  String get homeLabel => isKorean ? '홈' : 'Home';
  String get chatLabel => isKorean ? '대화' : 'Chat';
  String get historyLabel => isKorean ? '기록' : 'History';
  String get profileLabel => isKorean ? '프로필' : 'Profile';
  String get appLanguageSectionLabel => isKorean ? '앱 언어' : 'App language';
  String get appLanguageKoreanLabel => isKorean ? '한국어' : 'Korean';
  String get appLanguageEnglishLabel => isKorean ? '영어' : 'English';
  String get appLanguageSaveFailed => isKorean
      ? '앱 언어를 저장하지 못했어요. 다시 시도해 주세요.'
      : 'Could not save app language. Please try again.';
  String get preferenceChangeConfirmationTitle =>
      isKorean ? '변경하시겠습니까?' : 'Save this change?';
  String changeAppLanguageMessage(String language) => isKorean
      ? '앱 언어를 $language로 변경할까요?'
      : 'Change the app language to $language?';
  String changeLanguagePairMessage(String pair) =>
      isKorean ? '언어쌍을 $pair로 변경할까요?' : 'Change the language pair to $pair?';
  String get confirmChangeLabel => isKorean ? '변경' : 'Change';
  String get startConversationLabel =>
      isKorean ? '대화 시작하기' : 'START CONVERSATION';
  String get startConversationTooltip =>
      isKorean ? '대화 시작하기' : 'Start conversation';
  String get recentLabel => isKorean ? '최근 대화' : 'Recent';
  String get loadingRecentConversations =>
      isKorean ? '최근 대화를 불러오는 중...' : 'Loading recent conversations...';
  String get recentConversationsLoadFailed => isKorean
      ? '최근 대화를 불러오지 못했어요.'
      : 'Recent conversations could not be loaded.';
  String get updatingConversations =>
      isKorean ? '대화를 업데이트하는 중...' : 'Updating conversations...';
  String get homeEmptyTitle => isKorean ? '대화를 시작하세요' : 'Start a conversation';
  String get suggestedStartingPoints =>
      isKorean ? '대화 시작 아이디어' : 'Suggested starting points';
  String get showAllLabel => isKorean ? '모두 보기' : 'SHOW ALL';
  String get showLessLabel => isKorean ? '접기' : 'SHOW LESS';
  String get showMoreLabel => isKorean ? '더 보기' : 'SHOW MORE';
  String get updatingConversationsSemanticLabel =>
      isKorean ? '대화를 업데이트하는 중' : 'Updating conversations';
  String profileSemanticLabel(String name) =>
      isKorean ? '$name 프로필' : 'Profile for $name';
  String get accountLabel => isKorean ? '계정' : 'Account';
  String get languagePairSectionLabel => isKorean ? '언어쌍' : 'Language Pair';
  String get logOutLabel => isKorean ? '로그아웃' : 'LOG OUT';
  String get languagePairSaveFailed =>
      isKorean ? '언어쌍을 저장하지 못했어요.' : 'Language pair could not be saved.';
  String get startConversationTitle =>
      isKorean ? '대화 시작하기' : 'Start a conversation';
  String get freeChatDescription =>
      isKorean ? '내가 고른 주제로 대화하기' : 'Bring your own topic';
  String get roleplayTitle => isKorean ? '역할극' : 'Roleplay';
  String get roleplayDescription =>
      isKorean ? '현실 상황을 연습하기' : 'Practice a real-world situation';
  String get cancelLabel => isKorean ? '취소' : 'CANCEL';
  String get historyTitle => isKorean ? '대화 기록' : 'History';
  String get loadingHistory =>
      isKorean ? '대화 기록을 불러오는 중...' : 'Loading conversation history...';
  String get historyLoadFailed => isKorean
      ? '대화 기록을 불러오지 못했어요.'
      : 'Conversation history could not be loaded.';
  String get historyEmptyMessage => isKorean
      ? '대화를 시작하면 연습 기록이 여기에 보여요.'
      : 'Start a chat and your practice history will appear here.';
  String get noConversationsYetTitle =>
      isKorean ? '아직 대화가 없어요.' : 'No conversations yet.';
  String conversationCategory(String kind) => switch (kind) {
    'roleplay' => isKorean ? '역할극' : 'Roleplay',
    _ => isKorean ? '자유 대화' : 'Free chat',
  };
  String conversationPreview({
    required int messageCount,
    required bool isActive,
  }) {
    if (isKorean) {
      return '$messageCount개 메시지 · ${isActive ? '계속 대화하기' : '완료'}';
    }
    final String messageLabel = messageCount == 1 ? 'message' : 'messages';
    return '$messageCount $messageLabel · ${isActive ? 'Continue speaking' : 'Completed'}';
  }

  String recentConversationSemanticLabel(String category, String title) =>
      isKorean ? '$category 대화: $title' : '$category conversation: $title';
  String get topicPrepTitle => isKorean ? '주제 준비' : 'Topic Prep';
  String get preparingConversation =>
      isKorean ? '대화를 준비하는 중...' : 'Preparing your conversation...';
  String get topicPrepFailedTitle =>
      isKorean ? '이 주제를 준비하지 못했어요.' : 'Could not prepare this topic.';
  String get summaryLabel => isKorean ? '요약' : 'Summary';
  String get sourcesLabel => isKorean ? '출처' : 'Sources';
  String get chooseDirectionLabel =>
      isKorean ? '어떤 주제가 좋으세요?' : 'What would you like to talk about?';
  String get customFocusLabel =>
      isKorean ? '직접 입력하는 대화 방향' : 'Your own conversation focus';
  String get customFocusPlaceholder => isKorean
      ? '마음에 드는 주제가 없으면 직접 입력해보세요'
      : 'If none of these feel right, enter your own.';
  String get customFocusSubmitLabel => 'Submit';
  String get customFocusEmptyError =>
      isKorean ? '대화 방향을 입력해 주세요.' : 'Enter a conversation focus.';
  String get preparingCustomQuestions =>
      isKorean ? '질문을 준비하는 중...' : 'Preparing questions...';
  String get customFocusQuestionsFailed => isKorean
      ? '원하는 방향의 질문을 준비하지 못했어요. 다시 시도해 주세요.'
      : 'We could not prepare questions for that focus. Please try again.';
  String get regenerateDirectionsLabel => 'Show different directions';
  String get preparingDirections =>
      isKorean ? '새로운 대화 방향을 준비하는 중...' : 'Preparing new directions...';
  String get regenerateDirectionsFailed => isKorean
      ? '새로운 대화 방향을 준비하지 못했어요. 다시 시도해 주세요.'
      : 'We could not prepare new directions. Please try again.';
  String get pickFirstQuestionLabel =>
      isKorean ? '첫 질문 고르기' : 'Pick a first question';
  String get answerToBeginLabel => isKorean ? '답변하고 시작하기' : 'Answer to begin';
  String get tryOneOfTheseLabel =>
      isKorean ? '이 중 하나로 시도해 보세요' : 'Try one of these';
  String get chooseSituationTitle =>
      isKorean ? '상황을 골라 보세요' : 'Choose a situation';
  String get chooseSituationDescription => isKorean
      ? '연습할 현실 상황을 고르거나 직접 상황을 적어 보세요.'
      : 'Pick a real-world moment to practice, or write your own custom roleplay.';
  String get chooseDifficultyLabel =>
      isKorean ? '난이도 고르기' : 'Choose difficulty';
  String get differentSituationLabel =>
      isKorean ? '다른 상황을 원하나요?' : 'Want a different situation?';
  String get customRoleplayLabel => isKorean ? '직접 역할극 만들기' : 'CUSTOM ROLEPLAY';
  String get customRoleplaySemanticLabel => isKorean
      ? '직접 입력하는 역할극 상황 또는 내 역할'
      : 'Custom roleplay situation or your role';
  String roleplayScenarioSemanticLabel(String title) =>
      isKorean ? '역할극 상황: $title' : 'Roleplay scenario: $title';
  String get startRoleplayLabel => isKorean ? '역할극 시작하기' : 'START ROLEPLAY';
  String get chatMessageHint =>
      isKorean ? '메시지를 입력하세요...' : 'Type a message...';
  String recordingElapsedLabel(String elapsed) =>
      isKorean ? '녹음 중 $elapsed' : 'Recording $elapsed';
  String get stopRecordingTooltip => isKorean ? '녹음 중지' : 'Stop recording';
  String get voiceInputTooltip => isKorean ? '음성 입력' : 'Voice input';
  String get cancelRecordingTooltip => isKorean ? '녹음 취소' : 'Cancel recording';
  String get sendMessageTooltip => isKorean ? '메시지 보내기' : 'Send message';
  String roleplayDifficultyLabel(String value) {
    return switch (value) {
      'EASY' => isKorean ? '쉬움' : 'Easy',
      'NORMAL' => isKorean ? '보통' : 'Normal',
      'CHALLENGE' => isKorean ? '도전' : 'Challenge',
      _ => value,
    };
  }

  String roleplayDifficultyDescription(String value) {
    return switch (value) {
      'EASY' =>
        isKorean
            ? '짧은 문장과 천천히 진행되는 흐름으로 연습해요.'
            : 'Short prompts, clear context, and a gentle pace.',
      'NORMAL' =>
        isKorean
            ? '일상적인 속도와 자연스러운 추가 질문으로 대화해요.'
            : 'Natural everyday pacing with useful follow-up questions.',
      'CHALLENGE' =>
        isKorean
            ? '더 길고 정확한 답변이 필요한 질문에 도전해요.'
            : 'Unexpected follow-ups that invite longer, more precise answers.',
      _ => '',
    };
  }

  String pageLabel(int current, int count) =>
      isKorean ? '$count개 중 $current번째 페이지' : 'Page $current of $count';
  String sourceSemanticLabel(String title) =>
      isKorean ? '출처: $title' : 'Source: $title';
  String get typingSemanticLabel =>
      isKorean ? 'AI가 답변을 작성하는 중' : 'AI is typing';
  String firstQuestionSemanticLabel(int number, String question) => isKorean
      ? '첫 질문 $number: $question'
      : 'First question $number: $question';
  String get defaultLoadingLabel => isKorean ? '불러오는 중...' : 'Loading...';
  String get defaultErrorTitle =>
      isKorean ? '문제가 발생했어요.' : 'Something went wrong.';
  String get defaultEmptyTitle =>
      isKorean ? '아직 내용이 없어요.' : 'Nothing here yet.';
  String get grammarFeedbackSemanticLabel =>
      isKorean ? '문법 피드백' : 'Grammar feedback';
  String get showGrammarFeedbackLabel =>
      isKorean ? '문법 피드백 보기' : 'Show grammar feedback';
  String get hideGrammarFeedbackLabel =>
      isKorean ? '문법 피드백 숨기기' : 'Hide grammar feedback';
  String get grammarReasonLabel => isKorean ? '이유' : 'Why';
  String get splashTagline =>
      isKorean ? '무엇이든 이야기해요.' : 'Speak about anything.';
  String get tryAgainLabel => isKorean ? '다시 시도' : 'Try again';
  String get looksNaturalLabel => isKorean ? '자연스러워요' : 'Looks natural';
}

class AppOnboardingCopy {
  const AppOnboardingCopy({
    required this.backLabel,
    required this.skipLabel,
    required this.continueLabel,
    required this.getStartedLabel,
    required this.languagePair,
    required this.interest,
    required this.topicPrep,
    required this.feedback,
  });

  static const AppOnboardingCopy korean = AppOnboardingCopy(
    backLabel: '뒤로',
    skipLabel: '건너뛰기',
    continueLabel: '계속',
    getStartedLabel: '시작하기',
    languagePair: AppOnboardingPageCopy(
      title: '무엇을 연습할까요?',
      description: '대화 언어와 피드백 언어를 먼저 선택하세요.',
    ),
    interest: AppOnboardingInterestCopy(
      title: '진짜 관심사를\n이야기해요.',
      description: '뉴스, 취미, 스포츠, 여행처럼 마음에 있는 주제로 회화를 연습해요.',
      leftMessage: '어디로 가세요?',
      rightMessage: '다음 주에 오사카에 가요!',
      chips: <String>['오사카 맛집', '야구', 'AI 뉴스'],
    ),
    topicPrep: AppOnboardingTopicPrepCopy(
      title: '주제만 정하면,\n바로 이야기할 수 있는 질문이 준비돼요.',
      description: '대화하고 싶은 주제를 고르면, 바로 이야기할 수 있는 질문을 받아볼 수 있어요.',
      sectionLabel: '주제 요약',
      topicTitle: '커리어 전환\n준비하기',
      helperText: '대화를 위한 질문 3개가 준비됐어요.',
    ),
    feedback: AppOnboardingFeedbackCopy(
      title: '완벽하지 않아도 괜찮아요.\n대화하며 자연스럽게 배워요.',
      description: '재미있게 대화하고 자연스레 학습해요.',
      originalMessage: 'I go to Dotonbori yesterday.',
      correctionText: '제안: I went to Dotonbori yesterday.',
      reasonText: '이유: 과거 시제 + 장소',
    ),
  );

  static const AppOnboardingCopy english = AppOnboardingCopy(
    backLabel: 'BACK',
    skipLabel: 'SKIP',
    continueLabel: 'CONTINUE',
    getStartedLabel: 'GET STARTED',
    languagePair: AppOnboardingPageCopy(
      title: 'What do you want\nto practice?',
      description: 'Choose your conversation language and feedback language.',
    ),
    interest: AppOnboardingInterestCopy(
      title: 'Talk about what\nyou actually care about.',
      description:
          'Practice conversation with news, hobbies, sports, travel, or anything on your mind.',
      leftMessage: 'Where are you heading?',
      rightMessage: "I'm going to Osaka next week!",
      chips: <String>['OSAKA FOOD', 'BASEBALL', 'AI NEWS'],
    ),
    topicPrep: AppOnboardingTopicPrepCopy(
      title: 'Pick a topic,\nand questions are ready to get you talking.',
      description:
          'Choose what you want to talk about, and get questions you can answer right away.',
      sectionLabel: 'Topic summary',
      topicTitle: 'Navigating\nCareer Transitions',
      helperText: 'Three useful questions are ready for your conversation.',
    ),
    feedback: AppOnboardingFeedbackCopy(
      title: "You don't have to be perfect.\nLearn naturally as you chat.",
      description: 'Enjoy the conversation and let learning happen naturally.',
      originalMessage: 'I go to Dotonbori yesterday.',
      correctionText: 'Try: I went to Dotonbori yesterday.',
      reasonText: 'Why: past tense + place',
    ),
  );

  final String backLabel;
  final String skipLabel;
  final String continueLabel;
  final String getStartedLabel;
  final AppOnboardingPageCopy languagePair;
  final AppOnboardingInterestCopy interest;
  final AppOnboardingTopicPrepCopy topicPrep;
  final AppOnboardingFeedbackCopy feedback;
}

class AppOnboardingPageCopy {
  const AppOnboardingPageCopy({required this.title, required this.description});

  final String title;
  final String description;
}

class AppOnboardingInterestCopy extends AppOnboardingPageCopy {
  const AppOnboardingInterestCopy({
    required super.title,
    required super.description,
    required this.leftMessage,
    required this.rightMessage,
    required this.chips,
  });

  final String leftMessage;
  final String rightMessage;
  final List<String> chips;
}

class AppOnboardingTopicPrepCopy extends AppOnboardingPageCopy {
  const AppOnboardingTopicPrepCopy({
    required super.title,
    required super.description,
    required this.sectionLabel,
    required this.topicTitle,
    required this.helperText,
  });

  final String sectionLabel;
  final String topicTitle;
  final String helperText;
}

class AppOnboardingFeedbackCopy extends AppOnboardingPageCopy {
  const AppOnboardingFeedbackCopy({
    required super.title,
    required super.description,
    required this.originalMessage,
    required this.correctionText,
    required this.reasonText,
  });

  final String originalMessage;
  final String correctionText;
  final String reasonText;
}

class AppLoginCopy {
  const AppLoginCopy({
    required this.title,
    required this.description,
    required this.googleLabel,
    required this.tryAgainLabel,
    required this.topicCardTitle,
    required this.topicChips,
  });

  static const AppLoginCopy korean = AppLoginCopy(
    title: '내가 고른 주제로\n대화해요.',
    description: '나에게 중요한 이야기를 나누며 회화를 연습해요. 관심사가 대화를 이끌어요.',
    googleLabel: 'Google로 계속하기',
    tryAgainLabel: '다시 시도',
    topicCardTitle: '나의 주제',
    topicChips: <String>['글로벌 뉴스', '여행', '야구', '기술'],
  );

  static const AppLoginCopy english = AppLoginCopy(
    title: 'Practice conversation with your own topics.',
    description:
        'Build fluency by discussing what actually matters to you. Your interests lead the conversation.',
    googleLabel: 'CONTINUE WITH GOOGLE',
    tryAgainLabel: 'TRY AGAIN',
    topicCardTitle: 'Your topics',
    topicChips: <String>['GLOBAL NEWS', 'TRAVEL', 'BASEBALL', 'TECHNOLOGY'],
  );

  final String title;
  final String description;
  final String googleLabel;
  final String tryAgainLabel;
  final String topicCardTitle;
  final List<String> topicChips;
}
