import 'dart:async';
import 'dart:convert';
import 'dart:math';

/// 녹음 종료 또는 HTTP 요청부터의 경과 시간만 보관하는 로컬 진단 정보예요.
class LatencyTrace {
  LatencyTrace({this.origin = 'http_request'})
    : id = List<int>.generate(
        16,
        (_) => _random.nextInt(256),
      ).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();

  static final Random _random = Random.secure();
  static const Symbol _zoneKey = #voiceLatencyTrace;
  static LatencyTrace? get current => Zone.current[_zoneKey] as LatencyTrace?;

  final String id;
  final String origin;
  final Stopwatch _clock = Stopwatch()..start();
  bool _requestClaimed = false;
  bool _playbackStarted = false;

  int get elapsedMicroseconds => _clock.elapsedMicroseconds;

  /// 저장된 녹음을 재시도할 때는 이전 대기 시간을 이어 붙이지 않아요.
  LatencyTrace claimRequest() {
    if (_requestClaimed) {
      return LatencyTrace().._requestClaimed = true;
    }
    _requestClaimed = true;
    return this;
  }

  T duringDecode<T>(T Function() decode) =>
      runZoned(decode, zoneValues: <Object, Object>{_zoneKey: this});

  void mark(
    String stage, {
    String status = 'ok',
    int startedAtMicroseconds = 0,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    final int now = elapsedMicroseconds;
    try {
      // 단계당 한 줄만 출력해요. 원문·토큰·오디오는 기록하지 않아요.
      // ignore: avoid_print
      print(
        '[latency] ${jsonEncode(<String, Object?>{'source': 'mobile', 'trace_id': id, 'origin': origin, 'stage': stage, 'status': status, 'elapsed_ms': (now - startedAtMicroseconds) / 1000, 'since_start_ms': now / 1000, ...fields})}',
      );
    } on Object {
      // 진단 출력 실패가 요청이나 재생을 중단하지 않도록 해요.
    }
  }

  void markFirstPlayback(int requestedAtMicroseconds) {
    if (_playbackStarted) {
      return;
    }
    _playbackStarted = true;
    mark('playback_started', startedAtMicroseconds: requestedAtMicroseconds);
  }
}
