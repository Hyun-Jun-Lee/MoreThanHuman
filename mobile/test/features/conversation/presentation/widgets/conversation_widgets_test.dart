import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';
import 'package:curitalk/features/conversation/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatComposer sends trimmed text and supports voice input', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    String? sentMessage;
    int voiceCount = 0;

    await tester.pumpWidget(
      _themedApp(
        ChatComposer(
          controller: controller,
          onSend: (String message) => sentMessage = message,
          onVoiceInput: () => voiceCount += 1,
        ),
      ),
    );

    IconButton sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  I tried takoyaki.  ');
    await tester.pump();
    sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
    );
    expect(sendButton.onPressed, isNotNull);

    await tester.tap(find.byTooltip('Send message'));
    await tester.tap(find.byTooltip('Voice input'));
    expect(sentMessage, 'I tried takoyaki.');
    expect(voiceCount, 1);
  });

  testWidgets('ChatComposer shows and locks its sending state', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'Hello',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _themedApp(
        ChatComposer(controller: controller, isSending: true, onSend: (_) {}),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    final IconButton sendButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      sendButton.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      AppSemanticColors.light.selectedSurface,
    );
  });

  testWidgets('ChatComposer shows recording stop affordance', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'Typed draft',
    );
    addTearDown(controller.dispose);
    int voiceCount = 0;
    int cancelCount = 0;

    await tester.pumpWidget(
      _themedApp(
        ChatComposer(
          controller: controller,
          isRecording: true,
          recordingElapsedText: '0:05',
          onSend: (_) {},
          onVoiceInput: () => voiceCount += 1,
          onCancelVoiceInput: () => cancelCount += 1,
        ),
      ),
    );

    expect(find.byTooltip('Stop recording'), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.text('Recording 0:05'), findsOneWidget);
    expect(find.byTooltip('Cancel recording'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final IconButton sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded),
    );
    expect(sendButton.onPressed, isNull);

    await tester.tap(find.byTooltip('Stop recording'));
    await tester.tap(find.byTooltip('Cancel recording'));
    expect(voiceCount, 1);
    expect(cancelCount, 1);
  });

  testWidgets(
    'ChatComposer disables duplicate voice taps while voice is busy',
    (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _themedApp(
          ChatComposer(
            controller: controller,
            isVoiceBusy: true,
            voiceStatusLabel: 'Finishing recording...',
            onSend: (_) {},
            onVoiceInput: () {},
            onCancelVoiceInput: () {},
          ),
        ),
      );

      expect(find.text('Finishing recording...'), findsOneWidget);
      final IconButton voiceButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.mic_none_rounded),
      );
      expect(voiceButton.onPressed, isNull);
      final IconButton cancelButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close_rounded),
      );
      expect(cancelButton.onPressed, isNull);
    },
  );

  testWidgets('NaturalFeedbackBadge reports taps', (WidgetTester tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _themedApp(NaturalFeedbackBadge(onTap: () => tapCount += 1)),
    );

    expect(find.text('LOOKS NATURAL'), findsOneWidget);
    await tester.tap(find.byType(ActionChip));
    expect(tapCount, 1);
  });

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

  testWidgets('ChatBubble formats multi-sentence AI responses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const ChatBubble(
          message: 'Hi there!Welcome in.What can I get started for you today?',
          speaker: ChatSpeaker.assistant,
        ),
      ),
    );

    expect(find.text('Hi there!'), findsOneWidget);
    expect(find.text('Welcome in.'), findsOneWidget);
    expect(find.text('What can I get started for you today?'), findsOneWidget);
  });

  testWidgets('GrammarFeedbackCard highlights corrected text only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const GrammarFeedbackCard(
          suggestion: 'I was surprised.',
          explanation: 'Use the past tense for a completed action.',
          errors: <GrammarError>[
            GrammarError(
              original: 'surprise',
              corrected: 'surprised',
              explanation: 'Use the past tense for a completed action.',
            ),
          ],
        ),
      ),
    );

    expect(find.text('YOUR SENTENCE'), findsNothing);
    expect(find.text('SUGGESTED'), findsNothing);
    expect(find.text('I was surprise.'), findsNothing);
    expect(find.text('I was surprised.'), findsOneWidget);
    expect(find.text('WHY'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);
    expect(find.textContaining('Try'), findsNothing);
    expect(find.text('SHOW MORE'), findsNothing);
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

    final Text suggested = tester.widget<Text>(
      find.byKey(const ValueKey<String>('grammar-feedback-suggestion-text')),
    );
    final TextSpan suggestedCorrection = _spanWithText(
      suggested.textSpan! as TextSpan,
      'surprised',
    );
    expect(suggestedCorrection.style?.color, AppPalette.semanticSuccess);
    expect(suggestedCorrection.style?.fontWeight, FontWeight.w700);

    final Material card = tester.widget<Material>(
      find.descendant(
        of: find.byType(GrammarFeedbackCard),
        matching: find.byType(Material),
      ),
    );
    expect(card.color, AppSemanticColors.light.grammarSuggestionSurface);
  });

  testWidgets('GrammarFeedbackCard expands dense feedback text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const SizedBox(
          width: 220,
          child: GrammarFeedbackCard(
            suggestion: 'I went there yesterday.It was fun.',
            explanation:
                'Use past tense for completed actions.Add a space after punctuation.',
          ),
        ),
      ),
    );

    expect(find.text('SHOW MORE'), findsOneWidget);
    expect(find.text('SHOW LESS'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey<String>('grammar-feedback-suggestion-text'),
            ),
          )
          .maxLines,
      1,
    );

    await tester.tap(find.text('SHOW MORE'));
    await tester.pump();

    expect(find.text('SHOW LESS'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey<String>('grammar-feedback-suggestion-text'),
            ),
          )
          .maxLines,
      isNull,
    );
    expect(find.textContaining('I went there yesterday.'), findsOneWidget);
    expect(find.textContaining('It was fun.'), findsOneWidget);
    expect(find.text('Use past tense for completed actions.'), findsOneWidget);
    expect(find.text('Add a space after punctuation.'), findsOneWidget);
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

TextSpan _spanWithText(TextSpan parent, String text) {
  return parent.children!.whereType<TextSpan>().firstWhere(
    (TextSpan child) => child.text == text,
  );
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
