import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/domain/topic_starter_examples.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final Provider<LearningLanguageCode> topicStarterNativeLanguageProvider =
    Provider<LearningLanguageCode>((Ref ref) {
      return ref.watch(
        authControllerProvider.select(
          (AsyncValue<AuthSession> auth) =>
              auth.value?.user?.language.nativeLanguage ??
              LearningLanguageContext.defaultContext.nativeLanguage,
        ),
      );
    });

class TopicInputScreen extends ConsumerStatefulWidget {
  const TopicInputScreen({this.initialTopic, super.key});

  final String? initialTopic;

  @override
  ConsumerState<TopicInputScreen> createState() => _TopicInputScreenState();
}

class _TopicInputScreenState extends ConsumerState<TopicInputScreen> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTopic ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final LearningLanguageCode nativeLanguage = ref.watch(
      topicStarterNativeLanguageProvider,
    );
    final List<String> examples = TopicStarterExamples.forNativeLanguage(
      nativeLanguage,
    );
    return AppScaffold(
      appBar: AppBar(title: Text(copy.freeChatTitle)),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            copy.topicInputTitle,
            style: AppTypography.headlineLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            copy.topicInputDescription,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _controller,
            hintText: examples.first,
            errorText: _errorText,
            autofocus: true,
            textInputAction: TextInputAction.done,
            semanticLabel: copy.conversationTopicLabel,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _prepare(),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionLabel(copy.examplesLabel),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String example in examples)
                ActionChip(
                  label: Text(example),
                  onPressed: () {
                    _controller.text = example;
                    setState(() => _errorText = null);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppPrimaryButton(label: copy.prepareLabel, onPressed: _prepare),
        ],
      ),
    );
  }

  void _prepare() {
    final String topic = _controller.text.trim();
    if (topic.length < 2) {
      setState(() {
        _errorText = AppCopy.of(context).customRoleplayInputTooShort;
      });
      return;
    }
    context.push(
      '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent(topic)}',
    );
  }
}
