import 'dart:async';

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
    await tester.pump();

    expect(player.playedAudio?.format, 'mp3');
  });

  testWidgets('auto plays assistant audio once when requested', (
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
        autoPlayAudio: true,
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(player.playCount, 1);
    expect(find.text('Replay response'), findsOneWidget);

    await tester.pump();
    expect(player.playCount, 1);
  });

  testWidgets('prevents duplicate assistant audio playback taps', (
    WidgetTester tester,
  ) async {
    final Completer<void> playCompleter = Completer<void>();
    final _FakeConversationAudioPlayer player = _FakeConversationAudioPlayer(
      playCompleter: playCompleter,
    );
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.assistant,
          content: 'Sure.',
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

    await tester.tap(find.text('Play response'));
    await tester.pump();
    expect(find.text('Playing response'), findsOneWidget);

    await tester.tap(find.text('Playing response'), warnIfMissed: false);
    expect(player.playCount, 1);

    playCompleter.complete();
    await tester.pump();
    expect(find.text('Replay response'), findsOneWidget);

    await tester.tap(find.text('Replay response'));
    await tester.pump();
    expect(player.playCount, 2);
  });

  testWidgets('shows assistant playback failure without send retry', (
    WidgetTester tester,
  ) async {
    final _FakeConversationAudioPlayer player = _FakeConversationAudioPlayer(
      error: const ConversationAudioException(
        'Could not play audio response.',
        reason: ConversationAudioExceptionReason.playbackFailed,
      ),
    );
    await tester.pumpWidget(
      _app(
        ConversationMessage(
          id: 'assistant-message-id',
          conversationId: 'conversation-id',
          role: ConversationMessageRole.assistant,
          content: 'Sure.',
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

    await tester.tap(find.text('Play response'));
    await tester.pumpAndSettle();

    expect(
      find.text('Audio could not be played. Please try again.'),
      findsWidgets,
    );
    expect(find.text('Retry'), findsNothing);
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
    expect(
      find.text('Audio for this response is unavailable. You can keep chatting with the text.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });
}

Widget _app(
  ConversationMessage message, {
  ConversationAudioPlayer? audioPlayer,
  bool autoPlayAudio = false,
}) {
  return ProviderScope(
    overrides: [
      if (audioPlayer != null)
        conversationAudioPlayerProvider.overrideWithValue(audioPlayer),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ConversationMessageTile(
          message: message,
          autoPlayAudio: autoPlayAudio,
        ),
      ),
    ),
  );
}

class _FakeConversationAudioPlayer implements ConversationAudioPlayer {
  _FakeConversationAudioPlayer({this.playCompleter, this.error});

  final Completer<void>? playCompleter;
  final ConversationAudioException? error;
  VoiceAudioResponse? playedAudio;
  int playCount = 0;

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    playCount++;
    playedAudio = audio;
    final ConversationAudioException? playbackError = error;
    if (playbackError != null) {
      throw playbackError;
    }
    final Completer<void>? completer = playCompleter;
    if (completer != null) {
      await completer.future;
    }
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
