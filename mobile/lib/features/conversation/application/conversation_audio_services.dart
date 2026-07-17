import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum ConversationAudioExceptionReason {
  unknown,
  permissionDenied,
  emptyRecording,
  startFailed,
  stopFailed,
  playbackFailed,
}

class ConversationAudioException implements Exception {
  const ConversationAudioException(
    this.message, {
    this.reason = ConversationAudioExceptionReason.unknown,
    this.cause,
  });

  final String message;
  final ConversationAudioExceptionReason reason;
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

abstract interface class ConversationAudioRecorderBackend {
  Future<bool> hasPermission();

  Future<void> start(RecordConfig config, {required String path});

  Future<String?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class RecordAudioRecorderBackend implements ConversationAudioRecorderBackend {
  RecordAudioRecorderBackend({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(RecordConfig config, {required String path}) {
    return _recorder.start(config, path: path);
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

class ConversationAudioFileStore {
  const ConversationAudioFileStore();

  Future<Directory> temporaryDirectory() => getTemporaryDirectory();

  Future<List<int>> readBytes(String path) => File(path).readAsBytes();

  Future<void> deleteIfExists(String path) async {
    try {
      await File(path).delete();
    } on Object {
      // Temporary file cleanup is best effort and should not fail a turn.
    }
  }

  String basename(String path) => path.split(Platform.pathSeparator).last;
}

class RecordConversationAudioRecorder implements ConversationAudioRecorder {
  RecordConversationAudioRecorder({
    ConversationAudioRecorderBackend? backend,
    this.fileStore = const ConversationAudioFileStore(),
  }) : _backend = backend ?? RecordAudioRecorderBackend();

  final ConversationAudioRecorderBackend _backend;
  final ConversationAudioFileStore fileStore;
  String? _currentPath;

  @override
  Future<void> start() async {
    try {
      final bool hasPermission = await _backend.hasPermission();
      if (!hasPermission) {
        throw const ConversationAudioException(
          'Microphone permission is required.',
          reason: ConversationAudioExceptionReason.permissionDenied,
        );
      }
      final Directory directory = await fileStore.temporaryDirectory();
      final String path =
          '${directory.path}/curitalk-${DateTime.now().microsecondsSinceEpoch}.m4a';
      _currentPath = path;
      await _backend.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } on ConversationAudioException {
      rethrow;
    } on Object catch (error) {
      final String? currentPath = _currentPath;
      _currentPath = null;
      if (currentPath != null) {
        await fileStore.deleteIfExists(currentPath);
      }
      throw ConversationAudioException(
        'Could not start recording.',
        reason: ConversationAudioExceptionReason.startFailed,
        cause: error,
      );
    }
  }

  @override
  Future<ConversationAudioFile> stop() async {
    String resolvedPath = '';
    try {
      final String? path = await _backend.stop();
      resolvedPath = path ?? _currentPath ?? '';
      if (resolvedPath.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      final List<int> bytes = await fileStore.readBytes(resolvedPath);
      if (bytes.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      return ConversationAudioFile(
        bytes: bytes,
        filename: fileStore.basename(resolvedPath),
        contentType: 'audio/m4a',
      );
    } on ConversationAudioException {
      rethrow;
    } on Object catch (error) {
      throw ConversationAudioException(
        'Could not finish recording.',
        reason: ConversationAudioExceptionReason.stopFailed,
        cause: error,
      );
    } finally {
      if (resolvedPath.isNotEmpty) {
        _currentPath = null;
        await fileStore.deleteIfExists(resolvedPath);
      }
    }
  }

  @override
  Future<void> cancel() async {
    final String? currentPath = _currentPath;
    _currentPath = null;
    try {
      await _backend.cancel();
    } finally {
      if (currentPath != null) {
        await fileStore.deleteIfExists(currentPath);
      }
    }
  }

  @override
  Future<void> dispose() async {
    final String? currentPath = _currentPath;
    _currentPath = null;
    if (currentPath != null) {
      await fileStore.deleteIfExists(currentPath);
    }
    await _backend.dispose();
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
      final Completer<void> completed = Completer<void>();
      late final StreamSubscription<void> subscription;
      subscription = _player.onPlayerComplete.listen((_) {
        if (!completed.isCompleted) {
          completed.complete();
        }
      });
      try {
        await _player.play(BytesSource(bytes, mimeType: audio.contentType));
        await completed.future;
      } finally {
        await subscription.cancel();
      }
    } on Object catch (error) {
      throw ConversationAudioException(
        'Could not play audio response.',
        reason: ConversationAudioExceptionReason.playbackFailed,
        cause: error,
      );
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
