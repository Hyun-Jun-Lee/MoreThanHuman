import 'package:curitalk/core/network/api_exception.dart';

typedef ApiDataDecoder<T> = T Function(Object? json);

class ApiResponse<T> {
  const ApiResponse({required this.data, this.message});

  factory ApiResponse.fromJson(Object? json, ApiDataDecoder<T> decodeData) {
    if (json is! Map<String, dynamic>) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The server returned an invalid response.',
      );
    }

    final Object? success = json['success'];
    if (success is! bool) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The response is missing a valid success flag.',
      );
    }

    if (!success) {
      final Object? rawMessage = json['message'] ?? json['error'];
      throw ApiException(
        kind: ApiErrorKind.server,
        message: rawMessage is String && rawMessage.isNotEmpty
            ? rawMessage
            : 'The server could not complete the request.',
        details: json['details'],
      );
    }

    if (!json.containsKey('data')) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The response is missing its data field.',
      );
    }

    final Object? rawMessage = json['message'];
    if (rawMessage != null && rawMessage is! String) {
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The response contains an invalid message field.',
      );
    }

    return ApiResponse<T>(
      data: decodeData(json['data']),
      message: rawMessage as String?,
    );
  }

  final T data;
  final String? message;
}
