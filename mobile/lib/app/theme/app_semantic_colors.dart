import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.userMessageSurface,
    required this.onUserMessage,
    required this.aiMessageSurface,
    required this.onAiMessage,
    required this.grammarOriginalSurface,
    required this.onGrammarOriginal,
    required this.grammarSuggestionSurface,
    required this.onGrammarSuggestion,
    required this.topicReadySurface,
    required this.onTopicReady,
    required this.searchRetrySurface,
    required this.onSearchRetry,
    required this.selectedSurface,
    required this.onSelected,
    required this.disabledSurface,
    required this.onDisabled,
    required this.focusBorder,
    required this.scrim,
  });

  static const double disabledContentOpacity = 0.38;
  static const double scrimOpacity = 0.55;

  static final AppSemanticColors light = AppSemanticColors(
    userMessageSurface: AppPalette.inverseCanvas,
    onUserMessage: AppPalette.inverseInk,
    aiMessageSurface: AppPalette.canvas,
    onAiMessage: AppPalette.ink,
    grammarOriginalSurface: AppPalette.blockLilac,
    onGrammarOriginal: AppPalette.ink,
    grammarSuggestionSurface: AppPalette.blockBlue,
    onGrammarSuggestion: AppPalette.ink,
    topicReadySurface: AppPalette.blockLime,
    onTopicReady: AppPalette.ink,
    searchRetrySurface: AppPalette.blockCream,
    onSearchRetry: AppPalette.semanticWarning,
    selectedSurface: AppPalette.primary,
    onSelected: AppPalette.onPrimary,
    disabledSurface: AppPalette.surfaceSoft,
    onDisabled: AppPalette.inkSecondary.withValues(
      alpha: disabledContentOpacity,
    ),
    focusBorder: AppPalette.primary,
    scrim: AppPalette.overlayScrim.withValues(alpha: scrimOpacity),
  );

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ?? light;
  }

  final Color userMessageSurface;
  final Color onUserMessage;
  final Color aiMessageSurface;
  final Color onAiMessage;
  final Color grammarOriginalSurface;
  final Color onGrammarOriginal;
  final Color grammarSuggestionSurface;
  final Color onGrammarSuggestion;
  final Color topicReadySurface;
  final Color onTopicReady;
  final Color searchRetrySurface;
  final Color onSearchRetry;
  final Color selectedSurface;
  final Color onSelected;
  final Color disabledSurface;
  final Color onDisabled;
  final Color focusBorder;
  final Color scrim;

  @override
  AppSemanticColors copyWith({
    Color? userMessageSurface,
    Color? onUserMessage,
    Color? aiMessageSurface,
    Color? onAiMessage,
    Color? grammarOriginalSurface,
    Color? onGrammarOriginal,
    Color? grammarSuggestionSurface,
    Color? onGrammarSuggestion,
    Color? topicReadySurface,
    Color? onTopicReady,
    Color? searchRetrySurface,
    Color? onSearchRetry,
    Color? selectedSurface,
    Color? onSelected,
    Color? disabledSurface,
    Color? onDisabled,
    Color? focusBorder,
    Color? scrim,
  }) {
    return AppSemanticColors(
      userMessageSurface: userMessageSurface ?? this.userMessageSurface,
      onUserMessage: onUserMessage ?? this.onUserMessage,
      aiMessageSurface: aiMessageSurface ?? this.aiMessageSurface,
      onAiMessage: onAiMessage ?? this.onAiMessage,
      grammarOriginalSurface:
          grammarOriginalSurface ?? this.grammarOriginalSurface,
      onGrammarOriginal: onGrammarOriginal ?? this.onGrammarOriginal,
      grammarSuggestionSurface:
          grammarSuggestionSurface ?? this.grammarSuggestionSurface,
      onGrammarSuggestion: onGrammarSuggestion ?? this.onGrammarSuggestion,
      topicReadySurface: topicReadySurface ?? this.topicReadySurface,
      onTopicReady: onTopicReady ?? this.onTopicReady,
      searchRetrySurface: searchRetrySurface ?? this.searchRetrySurface,
      onSearchRetry: onSearchRetry ?? this.onSearchRetry,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      onSelected: onSelected ?? this.onSelected,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      onDisabled: onDisabled ?? this.onDisabled,
      focusBorder: focusBorder ?? this.focusBorder,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      userMessageSurface: Color.lerp(
        userMessageSurface,
        other.userMessageSurface,
        t,
      )!,
      onUserMessage: Color.lerp(onUserMessage, other.onUserMessage, t)!,
      aiMessageSurface: Color.lerp(
        aiMessageSurface,
        other.aiMessageSurface,
        t,
      )!,
      onAiMessage: Color.lerp(onAiMessage, other.onAiMessage, t)!,
      grammarOriginalSurface: Color.lerp(
        grammarOriginalSurface,
        other.grammarOriginalSurface,
        t,
      )!,
      onGrammarOriginal: Color.lerp(
        onGrammarOriginal,
        other.onGrammarOriginal,
        t,
      )!,
      grammarSuggestionSurface: Color.lerp(
        grammarSuggestionSurface,
        other.grammarSuggestionSurface,
        t,
      )!,
      onGrammarSuggestion: Color.lerp(
        onGrammarSuggestion,
        other.onGrammarSuggestion,
        t,
      )!,
      topicReadySurface: Color.lerp(
        topicReadySurface,
        other.topicReadySurface,
        t,
      )!,
      onTopicReady: Color.lerp(onTopicReady, other.onTopicReady, t)!,
      searchRetrySurface: Color.lerp(
        searchRetrySurface,
        other.searchRetrySurface,
        t,
      )!,
      onSearchRetry: Color.lerp(onSearchRetry, other.onSearchRetry, t)!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      onSelected: Color.lerp(onSelected, other.onSelected, t)!,
      disabledSurface: Color.lerp(disabledSurface, other.disabledSurface, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
      focusBorder: Color.lerp(focusBorder, other.focusBorder, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
