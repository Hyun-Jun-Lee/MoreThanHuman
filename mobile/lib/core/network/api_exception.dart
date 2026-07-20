import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  client,
  server,
  cancelled,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.details,
    this.cause,
  });

  factory ApiException.fromDio(DioException exception) {
    final int? statusCode = exception.response?.statusCode;
    final Object? responseData = exception.response?.data;
    final String message =
        _extractMessage(responseData) ??
        exception.message ??
        'The request could not be completed.';

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          kind: ApiErrorKind.timeout,
          message: 'The request timed out. Please try again.',
          statusCode: statusCode,
          cause: exception,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiException(
          kind: ApiErrorKind.network,
          message: 'Check your internet connection and try again.',
          statusCode: statusCode,
          cause: exception,
        );
      case DioExceptionType.cancel:
        return ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'The request was cancelled.',
          statusCode: statusCode,
          cause: exception,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          kind: _kindForStatus(statusCode),
          message: message,
          statusCode: statusCode,
          details: responseData,
          cause: exception,
        );
      case DioExceptionType.unknown:
        return ApiException(
          kind: ApiErrorKind.unknown,
          message: message,
          statusCode: statusCode,
          cause: exception,
        );
    }
  }

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? details;
  final Object? cause;

  static ApiErrorKind _kindForStatus(int? statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return ApiErrorKind.unauthorized;
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return ApiErrorKind.client;
    }
    if (statusCode != null && statusCode >= 500) {
      return ApiErrorKind.server;
    }
    return ApiErrorKind.unknown;
  }

  static String? _extractMessage(Object? data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    for (final String key in <String>['message', 'error', 'detail']) {
      final Object? value = data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    final Object? detail = data['detail'];
    if (detail is List<Object?>) {
      final List<String> messages = detail
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item['msg'])
          .whereType<String>()
          .toList();
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
