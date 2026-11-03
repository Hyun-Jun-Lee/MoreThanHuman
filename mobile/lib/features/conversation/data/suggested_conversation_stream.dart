import 'dart:convert';

import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/core/network/auth_token_interceptor.dart';
import 'package:dio/dio.dart';

/// HTTP 청크와 UTF-8 문자 경계가 일치하지 않아도 완성된 NDJSON 줄만 내보내요.
Stream<Map<String, dynamic>> decodeConversationEvents(
  Stream<List<int>> bytes,
) async* {
  await for (final String line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) continue;
    final Object? decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic> || decoded['event'] is! String) {
      throw const FormatException('Invalid conversation stream event.');
    }
    yield decoded;
  }
}

class SuggestedConversationStream {
  const SuggestedConversationStream(this.apiClient);

  final ApiClient apiClient;

  Stream<Map<String, dynamic>> start({
    required String topicId,
    required String requestId,
    required CancelToken cancelToken,
    required LatencyTrace trace,
  }) async* {
    final startedAt = trace.elapsedMicroseconds;
    var status = 'error';
    try {
      final Response<ResponseBody> response = await apiClient.dio
          .request<ResponseBody>(
            'conversations/start/free-chat/suggested/stream/',
            data: <String, String>{
              'topic_id': topicId,
              'start_request_id': requestId,
            },
            cancelToken: cancelToken,
            options: Options(
              method: 'POST',
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(minutes: 2),
              headers: <String, String>{
                'Accept': 'application/x-ndjson',
                'Idempotency-Key': requestId,
                'X-Request-ID': trace.id,
              },
              extra: <String, Object?>{
                AuthTokenInterceptor.requiresAuthKey: true,
              },
            ),
          );
      final ResponseBody? body = response.data;
      if (body == null) {
        throw const FormatException('Empty conversation stream.');
      }
      trace.mark('http_response', startedAtMicroseconds: startedAt);
      yield* decodeConversationEvents(body.stream.cast<List<int>>());
      status = 'ok';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } finally {
      trace.mark(
        'http_total',
        status: status,
        startedAtMicroseconds: startedAt,
      );
    }
  }
}
