import 'dart:convert';
import 'dart:typed_data';
import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/history/data/conversation_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses server pagination and requests the next offset', () async {
    final adapter = _Adapter();
    final client = ApiClient.create(
      tokenStorage: const _MemoryTokenStorage(),
      baseUrl: 'https://example.com/api/',
    );
    client.dio.httpClientAdapter = adapter;
    final repo = ApiConversationHistoryRepository(client);
    final page = await repo.list(offset: 20, limit: 20);
    expect(adapter.request!.path, 'conversations/');
    expect(adapter.request!.queryParameters, {'limit': 20, 'offset': 20});
    expect(page.items.single.id, 'conversation-id');
    expect(page.nextOffset, 21);
    expect(page.hasMore, isTrue);
    adapter.empty = true;
    final empty = await repo.list(offset: page.nextOffset);
    expect(empty.hasMore, isFalse);
  });
}

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  bool empty = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'results': empty
              ? []
              : [
                  {
                    'id': 'conversation-id',
                    'title': 'Coffee',
                    'conversation_type': 'FREE_CHAT',
                    'message_count': 2,
                    'status': 'ACTIVE',
                    'updated_at': '2026-09-22T10:00:00Z',
                  },
                ],
          'pagination': {
            'limit': 20,
            'offset': 20,
            'total_count': 42,
            'has_more': true,
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  const _MemoryTokenStorage();

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> readAccessToken() async => 'access-token';

  @override
  Future<String?> readDeviceId() async => 'installation-id';

  @override
  Future<AuthTokens?> readTokens() async => null;

  @override
  Future<void> writeDeviceId(String deviceId) async {}

  @override
  Future<void> writeTokens(AuthTokens tokens) async {}
}
