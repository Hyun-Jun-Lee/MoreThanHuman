import 'dart:async';
import 'dart:convert';

import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decode scopes do not leak and manual retries get a fresh trace', () {
    final LatencyTrace trace = LatencyTrace(origin: 'recording_stop');
    expect(trace.claimRequest(), same(trace));
    expect(trace.claimRequest().id, isNot(trace.id));
    expect(LatencyTrace.current, isNull);
    trace.duringDecode(() {
      expect(LatencyTrace.current, same(trace));
      final LatencyTrace other = LatencyTrace();
      other.duringDecode(() => expect(LatencyTrace.current, same(other)));
      expect(LatencyTrace.current, same(trace));
    });
    expect(LatencyTrace.current, isNull);
  });

  test('replay does not produce another first playback sample', () {
    final List<String> output = <String>[];
    runZoned(
      () {
        final LatencyTrace trace = LatencyTrace(origin: 'recording_stop');
        trace.markFirstPlayback(trace.elapsedMicroseconds);
        trace.markFirstPlayback(trace.elapsedMicroseconds);
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          output.add(line);
        },
      ),
    );
    expect(output, hasLength(1));
    final Map<String, dynamic> row =
        jsonDecode(output.single.substring('[latency] '.length))
            as Map<String, dynamic>;
    expect(row['stage'], 'playback_started');
    expect(row['origin'], 'recording_stop');
    expect(
      row['since_start_ms'],
      greaterThanOrEqualTo(row['elapsed_ms'] as num),
    );
  });
}
