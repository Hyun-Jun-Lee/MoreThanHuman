import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter/material.dart';

class LanguagePairSelector extends StatelessWidget {
  const LanguagePairSelector({
    required this.selected,
    required this.onChanged,
    required this.localeCode,
    this.enabled = true,
    super.key,
  });

  final LearningLanguageContext selected;
  final ValueChanged<LearningLanguageContext> onChanged;
  final String localeCode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final LearningLanguageContext option
            in LearningLanguageContext.supportedContexts) ...<Widget>[
          AppSelectionCard(
            title: option.pairLabel(localeCode),
            description: option.helperText(localeCode),
            selected: option == selected,
            onTap: enabled ? () => onChanged(option) : null,
            icon: Icon(_iconFor(option.targetLanguage)),
          ),
          if (option != LearningLanguageContext.supportedContexts.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
