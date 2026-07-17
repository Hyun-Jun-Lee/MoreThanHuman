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

  testWidgets('shows and plays assistant audio response', (
    WidgetTester tester,
  ) async {
    final _FakeConversationAudioPlayer player = _FakeConversationAudioPlayer();
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.assistant,
          content: 'Sure. What size would you like?',
          createdAt: DateTime.utc(2026, 7, 2),
          audio: const VoiceAudioResponse(
            contentType: 'audio/mpeg',
            base64: 'AAA=',
            format: 'mp3',
          ),
        ),
        audioPlayer: player,
      ),
    );

    expect(find.text('Play response'), findsOneWidget);
    await tester.tap(find.text('Play response'));

    expect(player.playedAudio?.format, 'mp3');
  });

  testWidgets('shows assistant audio error as non-blocking text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.assistant,
          content: 'Sure. What size would you like?',
          createdAt: DateTime.utc(2026, 7, 2),
          audioError: const VoiceAudioError(message: 'TTS unavailable.'),
        ),
      ),
    );

    expect(find.textContaining('Sure.'), findsOneWidget);
    expect(find.text('TTS unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}

Widget _app(
  ConversationMessage message, {
  ConversationAudioPlayer? audioPlayer,
}) {
  return ProviderScope(
    overrides: [
      if (audioPlayer != null)
        conversationAudioPlayerProvider.overrideWithValue(audioPlayer),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ConversationMessageTile(message: message)),
    ),
  );
}

class _FakeConversationAudioPlayer implements ConversationAudioPlayer {
  VoiceAudioResponse? playedAudio;

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    playedAudio = audio;
  }

  @override
  Future<void> dispose() async {}
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
