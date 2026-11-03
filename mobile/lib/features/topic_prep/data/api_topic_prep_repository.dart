import 'dart:convert';

import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_repository.dart';
import 'package:curitalk/features/topic_prep/domain/topic_prep_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiTopicPrepRepository
    implements
        TopicPrepRepository,
        TopicPrepStreamRepository,
        TopicPrepCustomFocusRepository {
  const ApiTopicPrepRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Stream<TopicPrepStreamEvent> prepareTopicStream(String topic) async* {
    final LatencyTrace trace = LatencyTrace(origin: 'topic_prep_request');
    var completed = false;
    try {
      final Response<ResponseBody> response = await apiClient.dio
          .request<ResponseBody>(
            'search/topic-prep/stream/',
            data: <String, String>{'topic': topic},
            options: Options(
              method: 'POST',
              responseType: ResponseType.stream,
              receiveTimeout: const Duration(minutes: 2),
              headers: <String, String>{
                'Accept': 'application/x-ndjson',
                'X-Request-ID': trace.id,
              },
              extra: <String, Object?>{
                AuthTokenInterceptor.requiresAuthKey: true,
              },
            ),
          );
      if (!(response.headers.value(Headers.contentTypeHeader) ?? '').startsWith(
        'application/x-ndjson',
      )) {
        throw const FormatException('Unexpected topic prep stream type.');
      }
      final ResponseBody? body = response.data;
      if (body == null) {
        throw const FormatException('Empty topic prep stream.');
      }
      await for (final String line
          in body.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        final Object? decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid topic prep stream event.');
        }
        switch (decoded['event']) {
          case 'summary_ready':
            final Object? summary = decoded['data'];
            if (summary is! String || summary.trim().isEmpty || completed) {
              throw const FormatException('Invalid topic prep summary.');
            }
            trace.mark('summary_ready');
            yield TopicPrepStreamEvent.summary(summary);
          case 'card_ready':
            if (completed) {
              throw const FormatException('Duplicate topic prep card.');
            }
            final TopicPrepResult result = TopicPrepResult.fromJson(
              decoded['data'],
            );
            completed = true;
            trace.mark('card_ready');
            yield TopicPrepStreamEvent.card(result);
          case 'error':
            throw const FormatException('Topic prep stream failed.');
          default:
            throw const FormatException('Unknown topic prep stream event.');
        }
      }
      if (!completed) {
        throw const FormatException(
          'Topic prep stream ended before card_ready.',
        );
      }
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<TopicPrepResult> prepareTopic(String topic) async {
    final ApiResponse<TopicPrepResult> response = await apiClient
        .post<TopicPrepResult>(
          'search/topic-prep/',
          data: <String, String>{'topic': topic},
          decodeData: TopicPrepResult.fromJson,
        );
    return response.data;
  }

  @override
  Future<CustomFocusQuestions> prepareCustomFocusQuestions({
    required String topic,
    required String customFocus,
  }) async {
    final ApiResponse<CustomFocusQuestions> response = await apiClient
        .post<CustomFocusQuestions>(
          'search/topic-prep/custom-questions/',
          data: <String, String>{'topic': topic, 'custom_focus': customFocus},
          decodeData: CustomFocusQuestions.fromJson,
        );
    return response.data;
  }

  @override
  Future<TopicPrepDirections> regenerateDirections({
    required String topic,
    required List<String> previousDirections,
  }) async {
    final ApiResponse<TopicPrepDirections> response = await apiClient
        .post<TopicPrepDirections>(
          'search/topic-prep/directions/',
          data: <String, Object>{
            'topic': topic,
            'previous_directions': previousDirections,
          },
          decodeData: TopicPrepDirections.fromJson,
        );
    return response.data;
  }
}

final Provider<TopicPrepRepository> topicPrepRepositoryProvider =
    Provider<TopicPrepRepository>((Ref ref) {
      return ApiTopicPrepRepository(ref.watch(apiClientProvider));
    });
