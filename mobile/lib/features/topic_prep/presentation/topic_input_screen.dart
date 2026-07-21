import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TopicInputScreen extends StatefulWidget {
  const TopicInputScreen({this.initialTopic, super.key});

  final String? initialTopic;

  @override
  State<TopicInputScreen> createState() => _TopicInputScreenState();
}

class _TopicInputScreenState extends State<TopicInputScreen> {
  static const List<String> _examples = <String>[
    'AI news this week',
    'Osaka food trip',
    'World Cup qualifier',
    'Apple WWDC update',
  ];

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
    return AppScaffold(
      appBar: AppBar(title: const Text('Free Chat')),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'What topic do you want to talk about?',
            style: AppTypography.headlineLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Bring a news story, hobby, trip idea, sports result, or anything you actually care about.',
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _controller,
            hintText: 'AI news this week',
            errorText: _errorText,
            autofocus: true,
            textInputAction: TextInputAction.done,
            semanticLabel: 'Conversation topic',
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _prepare(),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionLabel('Examples'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String example in _examples)
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
          AppPrimaryButton(label: 'PREPARE', onPressed: _prepare),
        ],
      ),
    );
  }

  void _prepare() {
    final String topic = _controller.text.trim();
    if (topic.length < 2) {
      setState(() {
        _errorText = 'Enter at least 2 characters.';
      });
      return;
    }
    context.push(
      '${AppRoute.topicPrep}?topic=${Uri.encodeQueryComponent(topic)}',
    );
  }
}
