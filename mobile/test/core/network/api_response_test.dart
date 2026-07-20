import 'package:curitalk/core/network/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiResponse parses the shared success envelope', () {
    final ApiResponse<String> response = ApiResponse<String>.fromJson(
      <String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'value': 'parsed'},
      },
      (Object? json) => (json! as Map<String, dynamic>)['value']! as String,
    );

    expect(response.data, 'parsed');
    expect(response.message, 'ok');
  });

  test('ApiResponse exposes a server-declared failure', () {
    expect(
      () => ApiResponse<void>.fromJson(<String, dynamic>{
        'success': false,
        'error': 'Search failed',
        'details': <String, dynamic>{'code': 'SEARCH_FAILED'},
      }, (_) {}),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.kind,
              'kind',
              ApiErrorKind.server,
            )
            .having(
              (ApiException error) => error.message,
              'message',
              'Search failed',
            ),
      ),
    );
  });

  test('ApiResponse rejects malformed envelopes', () {
    expect(
      () => ApiResponse<void>.fromJson(<String, dynamic>{
        'success': true,
      }, (_) {}),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
