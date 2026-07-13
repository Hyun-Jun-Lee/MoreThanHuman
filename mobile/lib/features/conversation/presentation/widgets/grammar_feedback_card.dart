import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/conversation/presentation/widgets/conversation_text_formatter.dart';
import 'package:flutter/material.dart';

class GrammarFeedbackCard extends StatelessWidget {
  const GrammarFeedbackCard({
    required this.suggestion,
    required this.explanation,
    this.suggestionLabel = 'Try',
    this.reasonLabel = 'Why',
    super.key,
  });

  final String suggestion;
  final String explanation;
  final String suggestionLabel;
  final String reasonLabel;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);
    final String displaySuggestion =
        ConversationTextFormatter.formatAssistantMessage(suggestion);
    final String displayExplanation =
        ConversationTextFormatter.formatAssistantMessage(explanation);

    return Semantics(
      container: true,
      label: 'Grammar feedback',
      child: Material(
        color: colors.grammarSuggestionSurface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: colors.onGrammarSuggestion,
                    size: AppSize.icon,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '$suggestionLabel: ',
                            style: AppTypography.button,
                          ),
                          TextSpan(
                            text: displaySuggestion,
                            style: AppTypography.bodySm,
                          ),
                        ],
                      ),
                      style: TextStyle(color: colors.onGrammarSuggestion),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppPalette.canvas,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.xs),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        child: Text(
                          reasonLabel.toUpperCase(),
                          style: AppTypography.captionMono.copyWith(
                            color: colors.onGrammarSuggestion,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        displayExplanation,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
