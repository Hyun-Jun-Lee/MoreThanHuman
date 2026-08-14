import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TopicPrepScreen extends ConsumerStatefulWidget {
  const TopicPrepScreen({required this.initialTopic, super.key});

  final String initialTopic;

  @override
  ConsumerState<TopicPrepScreen> createState() => _TopicPrepScreenState();
}

class _TopicPrepScreenState extends ConsumerState<TopicPrepScreen> {
  late String _topic;
  late final TextEditingController _answerController;
  late final ConversationAudioRecorder _recorder;
  Timer? _recordingTimer;
  TopicPrepDirectionType? _selectedDirection;
  int _selectedQuestionIndex = 0;
  String? _answerErrorText;
  _PrepVoiceInputState _voiceInput = const _PrepVoiceInputState.idle();

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic.trim();
    _answerController = TextEditingController();
    _recorder = ref.read(conversationAudioRecorderProvider);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_voiceInput.isRecordingActive) {
      unawaited(_recorder.cancel());
    }
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TopicPrepResult> result = ref.watch(
      topicPrepControllerProvider(_topic),
    );
    final StartConversationState startState = ref.watch(
      startConversationControllerProvider,
    );

    return AppScaffold(
      appBar: AppBar(title: const Text('Topic Prep')),
      body: result.when(
        loading: () => const AppAsyncStateView.loading(
          message: 'Preparing your conversation...',
        ),
        error: (_, _) => AppAsyncStateView.error(
          title: 'Could not prepare this topic.',
          message: 'Check your connection and try again.',
          onRetry: () {
            ref.read(topicPrepControllerProvider(_topic).notifier).reload();
          },
        ),
        data: (TopicPrepResult result) {
          if (!result.ready || result.card == null) {
            return _LowQualityTopicPrepView(
              result: result,
              onEditTopic: () => _editTopic(context),
              onExampleTopicSelected: _prepareAnotherTopic,
            );
          }
          return _ReadyTopicPrepView(
            card: result.card!,
            language: result.language,
            answerController: _answerController,
            selectedDirection: _selectedDirection,
            selectedQuestionIndex: _selectedQuestionIndex,
            answerErrorText: _answerErrorText,
            startErrorText: startState.errorMessage,
            isStarting: startState.isStarting,
            isRecording: _voiceInput.phase == _PrepVoiceInputPhase.recording,
            isVoiceBusy: _voiceInput.isBusy,
            recordingElapsedText:
                _voiceInput.phase == _PrepVoiceInputPhase.recording
                ? _formatElapsed(_voiceInput.elapsed)
                : null,
            voiceStatusLabel: _voiceInput.statusLabel,
            voiceErrorText: _voiceInput.errorMessage,
            onDirectionSelected: (TopicPrepDirectionType direction) {
              setState(() {
                _selectedDirection = direction;
                _selectedQuestionIndex = 0;
              });
            },
            onQuestionSelected: (int index) {
              setState(() => _selectedQuestionIndex = index);
            },
            onAnswerChanged: (_) {
              if (_answerErrorText != null) {
                setState(() => _answerErrorText = null);
              }
            },
            onStart: (String firstMessage) =>
                _startFreeChat(result.card!, firstMessage: firstMessage),
            onVoiceInput: () => _toggleVoiceInput(result.card!),
            onCancelVoiceInput: _voiceInput.isRecordingActive
                ? _cancelVoiceInput
                : null,
          );
        },
      ),
    );
  }

  void _prepareAnotherTopic(String topic) {
    setState(() {
      _topic = topic.trim();
      _selectedDirection = null;
      _selectedQuestionIndex = 0;
      _answerController.clear();
      _answerErrorText = null;
      _voiceInput = const _PrepVoiceInputState.idle();
    });
  }

  void _editTopic(BuildContext context) {
    context.go(
      '${AppRoute.topicInput}?topic=${Uri.encodeQueryComponent(_topic)}',
    );
  }

  Future<void> _startFreeChat(
    TopicPrepCard card, {
    required String firstMessage,
  }) async {
    if (firstMessage.length < 2) {
      setState(() => _answerErrorText = 'Enter at least 2 characters.');
      return;
    }

    final TopicPrepDirection direction = _resolveSelectedDirection(card);
    final String? selectedQuestion =
        direction.firstQuestions.isEmpty ||
            _selectedQuestionIndex >= direction.firstQuestions.length
        ? null
        : direction.firstQuestions[_selectedQuestionIndex];
    final ConversationResponse? response = await ref
        .read(startConversationControllerProvider.notifier)
        .startFreeChat(
          firstMessage: firstMessage,
          searchContext: card.summary,
          topic: card.topic,
          conversationDirection: direction.direction.value,
          selectedQuestion: selectedQuestion,
        );
    if (!mounted || response == null) {
      return;
    }
    context.go(AppRoute.conversationPath(response.conversationId));
  }

  Future<void> _startFreeChatWithAudio(
    TopicPrepCard card,
    ConversationAudioFile audioFile,
  ) async {
    final TopicPrepDirection direction = _resolveSelectedDirection(card);
    final String? selectedQuestion =
        direction.firstQuestions.isEmpty ||
            _selectedQuestionIndex >= direction.firstQuestions.length
        ? null
        : direction.firstQuestions[_selectedQuestionIndex];
    final ConversationResponse? response = await ref
        .read(startConversationControllerProvider.notifier)
        .startFreeChatWithAudio(
          audioFile: audioFile,
          searchContext: card.summary,
          topic: card.topic,
          conversationDirection: direction.direction.value,
          selectedQuestion: selectedQuestion,
        );
    if (!mounted || response == null) {
      return;
    }
    context.go(AppRoute.conversationPath(response.conversationId));
  }

  Future<void> _toggleVoiceInput(TopicPrepCard card) async {
    if (_voiceInput.phase == _PrepVoiceInputPhase.idle ||
        _voiceInput.phase == _PrepVoiceInputPhase.failed ||
        _voiceInput.phase == _PrepVoiceInputPhase.permissionDenied) {
      try {
        setState(() {
          _answerErrorText = null;
          _voiceInput = const _PrepVoiceInputState.starting();
        });
        await _recorder.start();
        if (!mounted) {
          return;
        }
        _startRecordingTimer();
        setState(() => _voiceInput = const _PrepVoiceInputState.recording());
      } on ConversationAudioException catch (error) {
        if (mounted) {
          _stopRecordingTimer();
          setState(
            () => _voiceInput =
                error.reason ==
                    ConversationAudioExceptionReason.permissionDenied
                ? _PrepVoiceInputState.permissionDenied(error.message)
                : _PrepVoiceInputState.failed(error.message),
          );
        }
      }
      return;
    }

    if (_voiceInput.phase != _PrepVoiceInputPhase.recording) {
      return;
    }

    try {
      final Duration recordingElapsed = _voiceInput.elapsed;
      _stopRecordingTimer();
      setState(() => _voiceInput = const _PrepVoiceInputState.stopping());
      final ConversationAudioFile audioFile = await _recorder.stop();
      if (!mounted) {
        return;
      }
      if (recordingElapsed < minimumVoiceRecordingDuration) {
        throw const ConversationAudioException(
          voiceNotRecognizedMessage,
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      if (audioFile.bytes.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      setState(() => _voiceInput = const _PrepVoiceInputState.sending());
      await _startFreeChatWithAudio(card, audioFile);
      if (mounted) {
        setState(() => _voiceInput = const _PrepVoiceInputState.idle());
      }
    } on ConversationAudioException catch (error) {
      if (mounted) {
        _stopRecordingTimer();
        setState(
          () => _voiceInput = _PrepVoiceInputState.failed(error.message),
        );
      }
    }
  }

  Future<void> _cancelVoiceInput() async {
    if (!_voiceInput.isRecordingActive) {
      return;
    }
    _stopRecordingTimer();
    try {
      await _recorder.cancel();
    } on Object {
      if (!mounted) {
        return;
      }
    }
    if (mounted) {
      setState(() => _voiceInput = const _PrepVoiceInputState.idle());
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(voiceRecordingTimerTick, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceInput = _voiceInput.copyWith(
          elapsed: _voiceInput.elapsed + voiceRecordingTimerTick,
        );
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatElapsed(Duration elapsed) {
    final int minutes = elapsed.inMinutes;
    final int seconds = elapsed.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  TopicPrepDirection _resolveSelectedDirection(TopicPrepCard card) {
    final TopicPrepDirectionType preferred =
        _selectedDirection ?? TopicPrepDirectionType.casualChat;
    return card.directions.firstWhere(
      (TopicPrepDirection direction) => direction.direction == preferred,
      orElse: () => card.directions.first,
    );
  }
}

class _ReadyTopicPrepView extends StatelessWidget {
  const _ReadyTopicPrepView({
    required this.card,
    required this.language,
    required this.answerController,
    required this.selectedQuestionIndex,
    required this.onDirectionSelected,
    required this.onQuestionSelected,
    required this.onAnswerChanged,
    required this.onStart,
    required this.onVoiceInput,
    this.selectedDirection,
    this.answerErrorText,
    this.startErrorText,
    this.voiceErrorText,
    this.recordingElapsedText,
    this.voiceStatusLabel,
    this.onCancelVoiceInput,
    this.isStarting = false,
    this.isRecording = false,
    this.isVoiceBusy = false,
  });

  final TopicPrepCard card;
  final LearningLanguageContext language;
  final TextEditingController answerController;
  final TopicPrepDirectionType? selectedDirection;
  final int selectedQuestionIndex;
  final String? answerErrorText;
  final String? startErrorText;
  final String? voiceErrorText;
  final String? recordingElapsedText;
  final String? voiceStatusLabel;
  final bool isStarting;
  final bool isRecording;
  final bool isVoiceBusy;
  final ValueChanged<TopicPrepDirectionType> onDirectionSelected;
  final ValueChanged<int> onQuestionSelected;
  final ValueChanged<String> onAnswerChanged;
  final ValueChanged<String> onStart;
  final VoidCallback onVoiceInput;
  final VoidCallback? onCancelVoiceInput;

  @override
  Widget build(BuildContext context) {
    final TopicPrepDirection direction = _selectedDirection;
    final List<String> questions = direction.firstQuestions;
    final String localeCode = Localizations.localeOf(context).languageCode;

    return ListView(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Text(card.topic, style: AppTypography.headlineLg),
        const SizedBox(height: AppSpacing.lg),
        AppColorBlockCard(
          color: AppPalette.blockCream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppSectionLabel('Summary'),
              const SizedBox(height: AppSpacing.md),
              Text(card.summary, style: AppTypography.body),
            ],
          ),
        ),
        if (card.sources.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const AppSectionLabel('Sources'),
          const SizedBox(height: AppSpacing.sm),
          for (final SearchSource source in card.sources.take(3))
            SourceLinkTile(title: source.title, url: source.url, onTap: () {}),
        ],
        const SizedBox(height: AppSpacing.xl),
        const AppSectionLabel('Choose direction'),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final TopicPrepDirection option in card.directions)
              AppSelectionChip(
                label: option.title,
                selected: option.direction == direction.direction,
                onSelected: (_) => onDirectionSelected(option.direction),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionLabel('Pick a first question'),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < questions.length; index++) ...<Widget>[
          AppSelectionCard(
            title: questions[index],
            selected: selectedQuestionIndex == index,
            onTap: () => onQuestionSelected(index),
            semanticLabel: 'First question ${index + 1}: ${questions[index]}',
          ),
          if (index != questions.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xl),
        const AppSectionLabel('Answer to begin'),
        const SizedBox(height: AppSpacing.md),
        ChatComposer(
          controller: answerController,
          hintText: language.firstAnswerHint(localeCode),
          enabled: !isStarting,
          isSending: isStarting,
          isRecording: isRecording,
          isVoiceBusy: isVoiceBusy,
          recordingElapsedText: recordingElapsedText,
          voiceStatusLabel: voiceStatusLabel,
          onSend: onStart,
          onVoiceInput: onVoiceInput,
          onCancelVoiceInput: onCancelVoiceInput,
          semanticLabel: language.firstAnswerSemanticLabel(localeCode),
          onChanged: onAnswerChanged,
        ),
        if (answerErrorText != null ||
            startErrorText != null ||
            voiceErrorText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            answerErrorText ?? startErrorText ?? voiceErrorText!,
            style: AppTypography.bodySm.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  TopicPrepDirection get _selectedDirection {
    final TopicPrepDirectionType preferred =
        selectedDirection ?? TopicPrepDirectionType.casualChat;
    return card.directions.firstWhere(
      (TopicPrepDirection direction) => direction.direction == preferred,
      orElse: () => card.directions.first,
    );
  }
}

enum _PrepVoiceInputPhase {
  idle,
  starting,
  recording,
  stopping,
  sending,
  failed,
  permissionDenied,
}

class _PrepVoiceInputState {
  const _PrepVoiceInputState._({
    required this.phase,
    this.elapsed = Duration.zero,
    this.errorMessage,
  });

  const _PrepVoiceInputState.idle() : this._(phase: _PrepVoiceInputPhase.idle);

  const _PrepVoiceInputState.starting()
    : this._(phase: _PrepVoiceInputPhase.starting);

  const _PrepVoiceInputState.recording({Duration elapsed = Duration.zero})
    : this._(phase: _PrepVoiceInputPhase.recording, elapsed: elapsed);

  const _PrepVoiceInputState.stopping()
    : this._(phase: _PrepVoiceInputPhase.stopping);

  const _PrepVoiceInputState.sending()
    : this._(phase: _PrepVoiceInputPhase.sending);

  const _PrepVoiceInputState.failed(String message)
    : this._(phase: _PrepVoiceInputPhase.failed, errorMessage: message);

  const _PrepVoiceInputState.permissionDenied(String message)
    : this._(
        phase: _PrepVoiceInputPhase.permissionDenied,
        errorMessage: message,
      );

  final _PrepVoiceInputPhase phase;
  final Duration elapsed;
  final String? errorMessage;

  bool get isBusy =>
      phase == _PrepVoiceInputPhase.starting ||
      phase == _PrepVoiceInputPhase.stopping ||
      phase == _PrepVoiceInputPhase.sending;

  bool get isRecordingActive =>
      phase == _PrepVoiceInputPhase.recording ||
      phase == _PrepVoiceInputPhase.starting ||
      phase == _PrepVoiceInputPhase.stopping;

  String? get statusLabel => switch (phase) {
    _PrepVoiceInputPhase.starting => 'Starting recording...',
    _PrepVoiceInputPhase.stopping => 'Finishing recording...',
    _PrepVoiceInputPhase.sending => 'Starting with your voice...',
    _ => null,
  };

  _PrepVoiceInputState copyWith({Duration? elapsed}) {
    return _PrepVoiceInputState._(
      phase: phase,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: errorMessage,
    );
  }
}

class _LowQualityTopicPrepView extends StatelessWidget {
  const _LowQualityTopicPrepView({
    required this.result,
    required this.onEditTopic,
    required this.onExampleTopicSelected,
  });

  final TopicPrepResult result;
  final VoidCallback onEditTopic;
  final ValueChanged<String> onExampleTopicSelected;

  @override
  Widget build(BuildContext context) {
    final String message =
        result.retryGuidance ??
        result.quality.retrySuggestion ??
        _TopicPrepFallbackCopy.forLanguage(
          result.language.feedbackLanguage,
        ).message;
    final _TopicPrepFallbackCopy copy = _TopicPrepFallbackCopy.forLanguage(
      result.language.feedbackLanguage,
    );

    return ListView(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        TopicRetryCard(
          title: copy.title,
          message: message,
          editTopicLabel: copy.editTopicLabel,
          tryAnotherIdeaLabel: copy.tryAnotherIdeaLabel,
          onEditTopic: onEditTopic,
          onTryAnotherIdea: result.exampleTopics.isEmpty
              ? onEditTopic
              : () => onExampleTopicSelected(result.exampleTopics.first),
        ),
        if (result.exampleTopics.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          const AppSectionLabel('Try one of these'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String topic in result.exampleTopics)
                ActionChip(
                  label: Text(topic),
                  onPressed: () => onExampleTopicSelected(topic),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TopicPrepFallbackCopy {
  const _TopicPrepFallbackCopy({
    required this.title,
    required this.message,
    required this.editTopicLabel,
    required this.tryAnotherIdeaLabel,
  });

  final String title;
  final String message;
  final String editTopicLabel;
  final String tryAnotherIdeaLabel;

  static _TopicPrepFallbackCopy forLanguage(
    LearningLanguageCode feedbackLanguage,
  ) {
    return switch (feedbackLanguage) {
      LearningLanguageCode.ko => const _TopicPrepFallbackCopy(
        title: '주제를 조금 더 구체화해요',
        message: '사람, 장소, 사건, 날짜 중 하나를 넣어 다시 시도해보세요.',
        editTopicLabel: '주제 수정',
        tryAnotherIdeaLabel: '다른 예시로 시도',
      ),
      LearningLanguageCode.zh => const _TopicPrepFallbackCopy(
        title: '请把话题再具体一点',
        message: '加入人物、地点、事件或日期后再试。',
        editTopicLabel: '修改话题',
        tryAnotherIdeaLabel: '试试其他示例',
      ),
      LearningLanguageCode.en => const _TopicPrepFallbackCopy(
        title: 'We need a clearer topic',
        message:
            'Try a more specific topic with a person, place, event, or date.',
        editTopicLabel: 'Edit topic',
        tryAnotherIdeaLabel: 'Try another idea',
      ),
    };
  }
}
