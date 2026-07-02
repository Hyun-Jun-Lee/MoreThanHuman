import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows completed no-error feedback as natural badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.user,
          content: 'That was fun.',
          createdAt: DateTime.utc(2026, 7, 2),
          grammarFeedback: _feedback(hasErrors: false),
        ),
      ),
    );

    expect(find.text('That was fun.'), findsOneWidget);
    expect(find.text('LOOKS NATURAL'), findsOneWidget);
  });

  testWidgets('shows completed error feedback as correction card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.user,
          content: 'I was surprise.',
          createdAt: DateTime.utc(2026, 7, 2),
          grammarFeedback: _feedback(hasErrors: true),
        ),
      ),
    );

    expect(find.textContaining('I was surprised.'), findsOneWidget);
    expect(find.text('Use the past participle after was.'), findsOneWidget);
  });
}

Widget _app(ConversationMessage message) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ConversationMessageTile(message: message)),
    ),
  );
}

GrammarFeedback _feedback({required bool hasErrors}) {
  return GrammarFeedback(
    id: 'feedback-id',
    messageId: 'message-id',
    originalText: hasErrors ? 'I was surprise.' : 'That was fun.',
    correctedText: hasErrors ? 'I was surprised.' : 'That was fun.',
    hasErrors: hasErrors,
    errors: hasErrors
        ? const <GrammarError>[
            GrammarError(
              original: 'surprise',
              corrected: 'surprised',
              explanation: 'Use the past participle after was.',
            ),
          ]
        : const <GrammarError>[],
    createdAt: DateTime.utc(2026, 7, 2),
  );
}
