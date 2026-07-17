import 'dart:io';

import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  test('recorder stop returns bytes and deletes the temporary file', () async {
    final _FakeAudioBackend backend = _FakeAudioBackend(
      stopPath: '/tmp/recording.m4a',
    );
    final _FakeAudioFileStore fileStore = _FakeAudioFileStore(
      bytesByPath: <String, List<int>>{
        '/tmp/recording.m4a': <int>[1, 2, 3],
      },
    );
    final RecordConversationAudioRecorder recorder =
        RecordConversationAudioRecorder(backend: backend, fileStore: fileStore);

    final ConversationAudioFile audioFile = await recorder.stop();

    expect(audioFile.filename, 'recording.m4a');
    expect(audioFile.bytes, <int>[1, 2, 3]);
    expect(fileStore.deletedPaths, <String>['/tmp/recording.m4a']);
  });

  test(
    'recorder stop rejects empty audio and deletes the temporary file',
    () async {
      final _FakeAudioBackend backend = _FakeAudioBackend(
        stopPath: '/tmp/empty.m4a',
      );
      final _FakeAudioFileStore fileStore = _FakeAudioFileStore(
        bytesByPath: <String, List<int>>{'/tmp/empty.m4a': <int>[]},
      );
      final RecordConversationAudioRecorder recorder =
          RecordConversationAudioRecorder(
            backend: backend,
            fileStore: fileStore,
          );

      await expectLater(
        recorder.stop(),
        throwsA(isA<ConversationAudioException>()),
      );
      expect(fileStore.deletedPaths, <String>['/tmp/empty.m4a']);
    },
  );

  test(
    'recorder cancel deletes the active temporary file best effort',
    () async {
      final Directory tempDirectory = await Directory.systemTemp.createTemp(
        'curitalk-audio-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final _FakeAudioBackend backend = _FakeAudioBackend();
      final _FakeAudioFileStore fileStore = _FakeAudioFileStore(
        temporaryDirectoryValue: tempDirectory,
      );
      final RecordConversationAudioRecorder recorder =
          RecordConversationAudioRecorder(
            backend: backend,
            fileStore: fileStore,
          );

      await recorder.start();
      await recorder.cancel();

      expect(backend.cancelCount, 1);
      expect(fileStore.deletedPaths.single, startsWith(tempDirectory.path));
    },
  );

  test('recorder cancel cleans up even when backend cancel fails', () async {
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'curitalk-audio-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final _FakeAudioBackend backend = _FakeAudioBackend(
      cancelError: StateError('cancel failed'),
    );
    final _FakeAudioFileStore fileStore = _FakeAudioFileStore(
      temporaryDirectoryValue: tempDirectory,
    );
    final RecordConversationAudioRecorder recorder =
        RecordConversationAudioRecorder(backend: backend, fileStore: fileStore);

    await recorder.start();

    await expectLater(recorder.cancel(), throwsA(isA<StateError>()));
    expect(fileStore.deletedPaths.single, startsWith(tempDirectory.path));
  });

  test('recorder dispose deletes the active temporary file', () async {
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'curitalk-audio-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final _FakeAudioBackend backend = _FakeAudioBackend();
    final _FakeAudioFileStore fileStore = _FakeAudioFileStore(
      temporaryDirectoryValue: tempDirectory,
    );
    final RecordConversationAudioRecorder recorder =
        RecordConversationAudioRecorder(backend: backend, fileStore: fileStore);

    await recorder.start();
    await recorder.dispose();

    expect(backend.disposeCount, 1);
    expect(fileStore.deletedPaths.single, startsWith(tempDirectory.path));
  });
}

class _FakeAudioBackend implements ConversationAudioRecorderBackend {
  _FakeAudioBackend({this.stopPath, this.cancelError});

  final String? stopPath;
  final Object? cancelError;
  int cancelCount = 0;
  int disposeCount = 0;
  String? startedPath;

  @override
  Future<void> cancel() async {
    cancelCount++;
    final Object? error = cancelError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedPath = path;
  }

  @override
  Future<String?> stop() async => stopPath;
}

class _FakeAudioFileStore extends ConversationAudioFileStore {
  _FakeAudioFileStore({
    this.temporaryDirectoryValue,
    this.bytesByPath = const <String, List<int>>{},
  });

  final Directory? temporaryDirectoryValue;
  final Map<String, List<int>> bytesByPath;
  final List<String> deletedPaths = <String>[];

  @override
  Future<Directory> temporaryDirectory() async {
    return temporaryDirectoryValue ?? Directory.systemTemp;
  }

  @override
  Future<List<int>> readBytes(String path) async {
    return bytesByPath[path] ?? <int>[];
  }

  @override
  Future<void> deleteIfExists(String path) async {
    deletedPaths.add(path);
  }
}
