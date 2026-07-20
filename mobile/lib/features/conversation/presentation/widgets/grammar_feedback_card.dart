import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/presentation/widgets/conversation_text_formatter.dart';
import 'package:flutter/material.dart';

class GrammarFeedbackCard extends StatefulWidget {
  const GrammarFeedbackCard({
    required this.suggestion,
    required this.explanation,
    this.reasonLabel = 'Why',
    super.key,
  });

  final String suggestion;
  final String explanation;
  final String reasonLabel;

  @override
  State<GrammarFeedbackCard> createState() => _GrammarFeedbackCardState();
}

class _GrammarFeedbackCardState extends State<GrammarFeedbackCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);
    final String displaySuggestion =
        ConversationTextFormatter.formatAssistantMessage(widget.suggestion);
    final String displayExplanation =
        ConversationTextFormatter.formatAssistantMessage(widget.explanation);
    final TextStyle suggestionStyle = AppTypography.bodySm.copyWith(
      color: colors.onGrammarSuggestion,
    );
    final TextStyle explanationStyle = AppTypography.bodySm.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Semantics(
      container: true,
      label: 'Grammar feedback',
      child: Material(
        color: colors.grammarSuggestionSurface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool canExpand =
                  _exceedsSingleLine(
                    text: displaySuggestion,
                    style: suggestionStyle,
                    maxWidth: constraints.maxWidth,
                    textScaler: MediaQuery.textScalerOf(context),
                  ) ||
                  _exceedsSingleLine(
                    text: displayExplanation,
                    style: explanationStyle,
                    maxWidth: constraints.maxWidth,
                    textScaler: MediaQuery.textScalerOf(context),
                  );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _FeedbackText(
                    text: displaySuggestion,
                    style: suggestionStyle,
                    expanded: _expanded || !canExpand,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ReasonBlock(
                    label: widget.reasonLabel,
                    text: displayExplanation,
                    style: explanationStyle,
                    expanded: _expanded || !canExpand,
                  ),
                  if (canExpand) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () {
                        setState(() => _expanded = !_expanded);
                      },
                      child: Text(_expanded ? 'SHOW LESS' : 'SHOW MORE'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _exceedsSingleLine({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: _singleLineText(text), style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }
}

class _ReasonBlock extends StatelessWidget {
  const _ReasonBlock({
    required this.label,
    required this.text,
    required this.style,
    required this.expanded,
  });

  final String label;
  final String text;
  final TextStyle style;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppPalette.canvas,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.captionMono.copyWith(
                color: colors.onGrammarSuggestion,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _FeedbackText(text: text, style: style, expanded: expanded),
      ],
    );
  }
}

class _FeedbackText extends StatelessWidget {
  const _FeedbackText({
    required this.text,
    required this.style,
    required this.expanded,
  });

  final String text;
  final TextStyle style;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Text(
        _singleLineText(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return AppParagraphText(text: text, style: style);
  }
}

String _singleLineText(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
