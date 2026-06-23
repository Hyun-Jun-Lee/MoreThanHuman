import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/conversation/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatBubble applies speaker alignment and semantic colors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const Column(
          children: <Widget>[
            ChatBubble(
              message: 'What did you eat there?',
              speaker: ChatSpeaker.assistant,
            ),
            ChatBubble(message: 'I tried takoyaki.', speaker: ChatSpeaker.user),
          ],
        ),
      ),
    );

    final List<Align> alignments = tester
        .widgetList<Align>(
          find.descendant(
            of: find.byType(ChatBubble),
            matching: find.byType(Align),
          ),
        )
        .toList();
    final List<DecoratedBox> bubbles = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ChatBubble),
            matching: find.byType(DecoratedBox),
          ),
        )
        .toList();
    final BoxDecoration assistantDecoration =
        bubbles[0].decoration as BoxDecoration;
    final BoxDecoration userDecoration = bubbles[1].decoration as BoxDecoration;

    expect(alignments[0].alignment, Alignment.centerLeft);
    expect(alignments[1].alignment, Alignment.centerRight);
    expect(assistantDecoration.color, AppSemanticColors.light.aiMessageSurface);
    expect(userDecoration.color, AppSemanticColors.light.userMessageSurface);
  });

  testWidgets('GrammarFeedbackCard renders suggestion and explanation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const GrammarFeedbackCard(
          suggestion: 'I went to Dotonbori yesterday.',
          explanation: 'Use the past tense for a completed action.',
        ),
      ),
    );

    expect(find.textContaining('I went to Dotonbori'), findsOneWidget);
    expect(find.text('WHY'), findsOneWidget);
    final Semantics semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(GrammarFeedbackCard),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere(
          (Semantics item) => item.properties.label == 'Grammar feedback',
        );
    expect(semantics.properties.label, 'Grammar feedback');

    final Material card = tester.widget<Material>(
      find.descendant(
        of: find.byType(GrammarFeedbackCard),
        matching: find.byType(Material),
      ),
    );
    expect(card.color, AppSemanticColors.light.grammarSuggestionSurface);
  });

  testWidgets('TypingIndicator exposes status with motion disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(const TypingIndicator(), disableAnimations: true),
    );

    expect(find.bySemanticsLabel('AI is typing'), findsOneWidget);
    for (int index = 0; index < 3; index += 1) {
      expect(find.byKey(ValueKey<String>('typing-dot-$index')), findsOneWidget);
    }

    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
  });
}

Widget _themedApp(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}
