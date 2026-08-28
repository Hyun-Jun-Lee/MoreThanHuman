import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter/material.dart';

class LanguagePairSelector extends StatelessWidget {
  const LanguagePairSelector({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final LearningLanguageContext selected;
  final ValueChanged<LearningLanguageContext> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final LearningLanguageContext option
            in LearningLanguageContext.supportedContexts) ...<Widget>[
          _buildOption(context, option),
          if (option != LearningLanguageContext.supportedContexts.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildOption(BuildContext context, LearningLanguageContext option) {
    final AppCopy copy = AppCopy.of(context);
    final bool isAvailable = option.isAvailableInMobileSelector;
    final bool isOptionEnabled = enabled && isAvailable;
    final String title = copy.languagePairLabel(
      nativeCode: option.nativeLanguage.code,
      targetCode: option.targetLanguage.code,
    );
    final String description = copy.languagePairDescription(
      nativeCode: option.nativeLanguage.code,
      targetCode: option.targetLanguage.code,
      feedbackCode: option.feedbackLanguage.code,
    );

    return AppSelectionCard(
      title: title,
      description: description,
      selected: option == selected,
      onTap: isOptionEnabled ? () => onChanged(option) : null,
      icon: Icon(_iconFor(option.targetLanguage)),
      trailing: isAvailable
          ? null
          : Tooltip(
              message: copy.comingSoonLabel,
              child: Icon(
                Icons.lock_clock_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      semanticLabel: isAvailable
          ? null
          : '$title, ${copy.comingSoonLabel}',
    );
  }

  static IconData _iconFor(LearningLanguageCode targetLanguage) {
    return switch (targetLanguage) {
      LearningLanguageCode.ko => Icons.language_rounded,
      LearningLanguageCode.en => Icons.chat_bubble_outline_rounded,
      LearningLanguageCode.zh => Icons.translate_rounded,
    };
  }
}
