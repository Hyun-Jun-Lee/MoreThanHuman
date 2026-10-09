import 'dart:math';

import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/core/network/auth_token_interceptor.dart';
import 'package:curitalk/features/conversation/data/suggested_conversation_stream.dart';
import 'package:dio/dio.dart';

String newConversationRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class StreamTurnStatus {
  const StreamTurnStatus({
    required this.turnId,
    required this.status,
    required this.audioStatus,
    this.attemptId,
    this.userMessageId,
    this.assistantMessageId,
    this.conversationId,
  });

  factory StreamTurnStatus.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['turn_id'] is! String ||
        value['status'] is! String ||
        value['audio_status'] is! String) {
      throw const FormatException('Invalid stream turn status.');
    }
    return StreamTurnStatus(
      turnId: value['turn_id'] as String,
      status: value['status'] as String,
      audioStatus: value['audio_status'] as String,
      attemptId: value['attempt_id'] as String?,
      userMessageId: value['user_message_id'] as String?,
      assistantMessageId: value['assistant_message_id'] as String?,
      conversationId: value['conversation_id'] as String?,
    );
  }

  final String turnId;
  final String status;
  final String audioStatus;
  final String? attemptId;
  final String? userMessageId;
  final String? assistantMessageId;
  final String? conversationId;
}

class ConversationStreamApi {
  const ConversationStreamApi(this.client);

  final ApiClient client;

  Stream<Map<String, dynamic>> events({
    required String path,
    required CancelToken cancelToken,
    Object? data,
    String? idempotencyKey,
    LatencyTrace? trace,
  }) async* {
    final startedAt = trace?.elapsedMicroseconds ?? 0;
    var result = 'error';
    try {
      final response = await client.dio.request<ResponseBody>(
        path,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: 'POST',
          responseType: ResponseType.stream,
          contentType: data is FormData
              ? Headers.multipartFormDataContentType
              : null,
          receiveTimeout: const Duration(minutes: 5),
          headers: <String, String>{
            'Accept': 'application/x-ndjson',
            'Idempotency-Key': ?idempotencyKey,
            'X-Request-ID': ?trace?.id,
          },
          extra: <String, Object?>{AuthTokenInterceptor.requiresAuthKey: true},
        ),
      );
      if (!(response.headers.value(Headers.contentTypeHeader) ?? '').startsWith(
        'application/x-ndjson',
      )) {
        throw const FormatException('Unexpected conversation stream type.');
      }
      final body = response.data;
      if (body == null) {
        throw const FormatException('Empty conversation stream.');
      }
      trace?.mark('http_response', startedAtMicroseconds: startedAt);
      yield* decodeConversationEvents(body.stream.cast<List<int>>());
      result = 'ok';
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } finally {
      trace?.mark(
        'http_total',
        status: result,
        startedAtMicroseconds: startedAt,
      );
    }
  }

  Future<StreamTurnStatus> status(String turnId) async {
    final response = await client.get<StreamTurnStatus>(
      'conversations/turns/$turnId/',
      decodeData: StreamTurnStatus.fromJson,
    );
    return response.data;
  }

  Future<StreamTurnStatus> statusForRequest(String requestId) async {
    final response = await client.get<StreamTurnStatus>(
      'conversations/turns/by-request/$requestId/',
      decodeData: StreamTurnStatus.fromJson,
    );
    return response.data;
  }

  Future<List<StreamTurnStatus>> unresolved(String conversationId) async {
    final response = await client.get<List<StreamTurnStatus>>(
      'conversations/$conversationId/turns/',
      decodeData: (value) {
        if (value is! List) throw const FormatException('Invalid turn list.');
        return value.map(StreamTurnStatus.fromJson).toList(growable: false);
      },
    );
    return response.data;
  }

  static FormData audioForm({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    return FormData.fromMap(<String, Object?>{
      'audio_file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
  }
}
