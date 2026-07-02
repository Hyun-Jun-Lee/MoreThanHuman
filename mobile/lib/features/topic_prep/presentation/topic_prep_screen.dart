import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
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
  TopicPrepDirectionType? _selectedDirection;
  int _selectedQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic.trim();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TopicPrepResult> result = ref.watch(
      topicPrepControllerProvider(_topic),
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
            selectedDirection: _selectedDirection,
            selectedQuestionIndex: _selectedQuestionIndex,
            onDirectionSelected: (TopicPrepDirectionType direction) {
              setState(() {
                _selectedDirection = direction;
                _selectedQuestionIndex = 0;
              });
            },
            onQuestionSelected: (int index) {
              setState(() => _selectedQuestionIndex = index);
            },
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
    });
  }

  void _editTopic(BuildContext context) {
    context.go(
      '${AppRoute.topicInput}?topic=${Uri.encodeQueryComponent(_topic)}',
    );
  }
}

class _ReadyTopicPrepView extends StatelessWidget {
  const _ReadyTopicPrepView({
    required this.card,
    required this.selectedQuestionIndex,
    required this.onDirectionSelected,
    required this.onQuestionSelected,
    this.selectedDirection,
  });

  final TopicPrepCard card;
  final TopicPrepDirectionType? selectedDirection;
  final int selectedQuestionIndex;
  final ValueChanged<TopicPrepDirectionType> onDirectionSelected;
  final ValueChanged<int> onQuestionSelected;

  @override
  Widget build(BuildContext context) {
    final TopicPrepDirection direction = _selectedDirection;
    final List<String> questions = direction.firstQuestions;

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
        const SizedBox(height: AppSpacing.xxl),
        AppPrimaryButton(label: 'START ANSWERING', onPressed: null),
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
        'Try a more specific topic with a person, place, event, or date.';

    return ListView(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        TopicRetryCard(
          message: message,
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
