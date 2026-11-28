import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/home/application/weekly_topics_controller.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 홈과 같은 조회·캐시를 사용하되 화면 진입마다 새 무작위 목록을 받아요.
final topicInputTopicsProvider =
    AsyncNotifierProvider.autoDispose<WeeklyTopicsController, WeeklyTopics>(
      WeeklyTopicsController.new,
    );

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
  String? _selectedExample;
  String? _recommendedTopic;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTopic ?? '');
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleTextChanged() {
    setState(() {
      _selectedExample = null;
      if (_controller.text.trim() != _recommendedTopic) {
        _recommendedTopic = null;
      }
      _errorText = null;
    });
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus && _recommendedTopic != null) {
      _controller.clear();
    }
    setState(() {
      if (_focusNode.hasFocus) _selectedExample = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final List<WeeklyTopic> examples =
        ref.watch(topicInputTopicsProvider).value?.topics.take(6).toList() ??
        const <WeeklyTopic>[];
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
          if (examples.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg + AppSpacing.xl),
            AppSectionLabel(copy.examplesLabel, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final WeeklyTopic topic in examples)
                  Builder(
                    builder: (BuildContext context) {
                      final String example = topic.text;
                      final bool selected = _selectedExample == example;
                      return Semantics(
                        key: ValueKey<String>('topic-example-${topic.id}'),
                        button: true,
                        selected: selected,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            _controller.text = example;
                            _focusNode.unfocus();
                            setState(() {
                              _selectedExample = example;
                              _recommendedTopic = example;
                              _errorText = null;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
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
      Uri(
        path: AppRoute.topicPrep,
        queryParameters: {
          'topic': topic,
          if (_recommendedTopic == topic) 'recommended': 'true',
        },
      ).toString(),
    );
  }
}
