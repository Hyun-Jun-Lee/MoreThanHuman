import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/domain/conversation_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class ConversationAccessRepository {
  Future<ConversationAccess> getAccess();
  Future<ConversationTurnAccess> getTurnAccess(String conversationId);
  Future<void> activate(String conversationId, {String? replaceConversationId});
  Future<void> deactivate(String conversationId);
}

class ApiConversationAccessRepository implements ConversationAccessRepository {
  const ApiConversationAccessRepository(this.client);

  final ApiClient client;

  @override
  Future<ConversationAccess> getAccess() async {
    final response = await client.get<ConversationAccess>(
      'conversations/access/',
      decodeData: ConversationAccess.fromJson,
    );
    return response.data;
  }

  @override
  Future<ConversationTurnAccess> getTurnAccess(String conversationId) async {
    final response = await client.get<ConversationTurnAccess>(
      'conversations/$conversationId/access/',
      decodeData: ConversationTurnAccess.fromJson,
    );
    return response.data;
  }

  @override
  Future<void> activate(
    String conversationId, {
    String? replaceConversationId,
  }) async {
    await client.post<Object?>(
      'conversations/$conversationId/activate/',
      data: {'replace_conversation_id': replaceConversationId},
      decodeData: (value) => value,
    );
  }

  @override
  Future<void> deactivate(String conversationId) async {
    await client.post<Object?>(
      'conversations/$conversationId/deactivate/',
      data: {},
      decodeData: (value) => value,
    );
  }
}

final conversationAccessRepositoryProvider =
    Provider<ConversationAccessRepository>(
      (ref) => ApiConversationAccessRepository(ref.watch(apiClientProvider)),
    );

final conversationAccessProvider = FutureProvider<ConversationAccess>((
  ref,
) async {
  final session = ref.watch(authControllerProvider).value;
  if (session == null || !session.isAuthenticated) {
    return const ConversationAccess.disabled();
  }
  try {
    return await ref.watch(conversationAccessRepositoryProvider).getAccess();
  } on Object {
    // 조회 실패 시 UI는 잠금을 추정하지 않아요. 서버가 생성 한도를 다시 검사해요.
    return const ConversationAccess.disabled();
  }
});

final conversationTurnAccessProvider =
    FutureProvider.family<ConversationTurnAccess, String>((
      ref,
      conversationId,
    ) async {
      final session = ref.watch(authControllerProvider).value;
      if (session == null || !session.isAuthenticated) {
        return const ConversationTurnAccess.disabled();
      }
      try {
        return await ref
            .watch(conversationAccessRepositoryProvider)
            .getTurnAccess(conversationId);
      } on Object {
        return const ConversationTurnAccess.disabled();
      }
    });
