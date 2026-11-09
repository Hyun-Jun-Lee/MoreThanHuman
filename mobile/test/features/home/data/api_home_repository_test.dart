import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/data/api_home_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home fetches every conversation page in order', () async {
    final adapter = _PagedConversationsAdapter();
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..httpClientAdapter = adapter,
    );

    final conversations = await ApiHomeRepository(
      client,
    ).listRecentConversations();

    expect(conversations.length, 101);
    expect(conversations.first.id, 'conversation-1');
    expect(conversations.last.id, 'conversation-101');
    expect(adapter.offsets, [0, 100]);
  });
}

class _PagedConversationsAdapter implements HttpClientAdapter {
  final List<int> offsets = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final offset = options.queryParameters['offset'] as int;
    final limit = options.queryParameters['limit'] as int;
    offsets.add(offset);
    expect(options.path, 'conversations/');
    expect(limit, 100);
    final count = offset == 0 ? 100 : 1;
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'results': List.generate(count, (index) {
            final number = offset + index + 1;
            return {
              'id': 'conversation-$number',
              'title': 'Conversation $number',
              'conversation_type': 'FREE_CHAT',
              'message_count': 1,
              'status': 'ACTIVE',
              'updated_at': '2026-11-08T00:00:00Z',
            };
          }),
          'pagination': {'has_more': offset == 0},
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
