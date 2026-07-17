import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ConversationAudioException implements Exception {
  const ConversationAudioException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class ConversationAudioRecorder {
  Future<void> start();

  Future<ConversationAudioFile> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class RecordConversationAudioRecorder implements ConversationAudioRecorder {
  RecordConversationAudioRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _currentPath;

  @override
  Future<void> start() async {
    try {
      final bool hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const ConversationAudioException(
          'Microphone permission is required.',
        );
      }
      final Directory directory = await getTemporaryDirectory();
      final String path =
          '${directory.path}/curitalk-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _currentPath = path;
    } on ConversationAudioException {
      rethrow;
    } on Object catch (error) {
      throw ConversationAudioException('Could not start recording.', error);
    }
  }

  @override
  Future<ConversationAudioFile> stop() async {
    try {
      final String? path = await _recorder.stop();
      final String resolvedPath = path ?? _currentPath ?? '';
      if (resolvedPath.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
        );
      }
      final File file = File(resolvedPath);
      final List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
        );
      }
      _currentPath = null;
      return ConversationAudioFile(
        bytes: bytes,
        filename: resolvedPath.split(Platform.pathSeparator).last,
        contentType: 'audio/m4a',
      );
    } on ConversationAudioException {
      rethrow;
    } on Object catch (error) {
      throw ConversationAudioException('Could not finish recording.', error);
    }
  }

  @override
  Future<void> cancel() async {
    _currentPath = null;
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

abstract interface class ConversationAudioPlayer {
  Future<void> play(VoiceAudioResponse audio);

  Future<void> dispose();
}

class AudioplayersConversationAudioPlayer implements ConversationAudioPlayer {
  AudioplayersConversationAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    try {
      final Uint8List bytes = base64Decode(audio.base64);
      await _player.play(BytesSource(bytes, mimeType: audio.contentType));
    } on Object catch (error) {
      throw ConversationAudioException('Could not play audio response.', error);
    }
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}

final conversationAudioRecorderProvider = Provider<ConversationAudioRecorder>((
  Ref ref,
) {
  final RecordConversationAudioRecorder recorder =
      RecordConversationAudioRecorder();
  ref.onDispose(() {
    recorder.dispose();
  });
  return recorder;
});

final conversationAudioPlayerProvider = Provider<ConversationAudioPlayer>((
  Ref ref,
) {
  final AudioplayersConversationAudioPlayer player =
      AudioplayersConversationAudioPlayer();
  ref.onDispose(() {
    player.dispose();
  });
  return player;
});
