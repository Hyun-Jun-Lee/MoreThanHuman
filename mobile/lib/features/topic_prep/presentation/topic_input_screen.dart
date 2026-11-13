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
  late final FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTopic ?? '');
    _focusNode = FocusNode();
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.sm,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: AppPrimaryButton(
          label: copy.topicInputStartLabel,
          onPressed: _controller.text.trim().isEmpty ? null : _prepare,
          trailing: const Icon(Icons.arrow_forward, size: 18),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              copy.topicInputTitle,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.headlineLg.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.topicInputDescription,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            key: const ValueKey<String>('topic-input-card'),
            height: 80,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppPalette.blockCream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _focusNode.hasFocus ? Colors.black : Colors.transparent,
                width: _focusNode.hasFocus ? 2 : 1,
              ),
            ),
            child: Semantics(
              textField: true,
              label: copy.conversationTopicLabel,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                expands: true,
                maxLines: null,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _prepare(),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  hintText: copy.topicInputHint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg + AppSpacing.xl),
          AppSectionLabel(copy.examplesLabel, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
            mainAxisExtent: 76,
            children: <Widget>[
              for (final String example in examples)
                Builder(
                  builder: (BuildContext context) {
                    final bool selected = _controller.text.trim() == example;
                    return Semantics(
                      button: true,
                      selected: selected,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          _controller.text = example;
                          _focusNode.unfocus();
                          setState(() => _errorText = null);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppPalette.blockCream
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            example,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
