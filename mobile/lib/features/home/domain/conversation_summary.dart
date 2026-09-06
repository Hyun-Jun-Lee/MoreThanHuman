enum ConversationKind { freeChat, roleplay }

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.kind,
    required this.messageCount,
    required this.isActive,
    required this.updatedAt,
  });

  factory ConversationSummary.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Conversation must be a JSON object.');
    }

    final Object? id = json['id'];
    final Object? rawTitle = json['title'];
    final Object? rawType = json['conversation_type'];
    final Object? messageCount = json['message_count'];
    final Object? status = json['status'];
    final DateTime? updatedAt = DateTime.tryParse('${json['updated_at']}');
    if (id is! String ||
        id.isEmpty ||
        rawType is! String ||
        messageCount is! int ||
        messageCount < 0 ||
        status is! String ||
        updatedAt == null) {
      throw const FormatException('Conversation payload is invalid.');
    }

    final ConversationKind kind = switch (rawType) {
      'FREE_CHAT' => ConversationKind.freeChat,
      'ROLE_PLAYING' => ConversationKind.roleplay,
      _ => throw const FormatException('Conversation type is invalid.'),
    };
    if (status != 'ACTIVE' && status != 'COMPLETED') {
      throw const FormatException('Conversation status is invalid.');
    }
    final String? title = rawTitle is String && rawTitle.trim().isNotEmpty
        ? rawTitle.trim()
        : null;
    final Object? roleCharacter = json['role_character'];
    final String? normalizedRoleCharacter =
        roleCharacter is String && roleCharacter.trim().isNotEmpty
        ? roleCharacter.trim()
        : null;
    return ConversationSummary(
      id: id,
      title:
          title ??
          (kind == ConversationKind.roleplay && normalizedRoleCharacter != null
              ? normalizedRoleCharacter
              : 'Untitled conversation'),
      kind: kind,
      messageCount: messageCount,
      isActive: status == 'ACTIVE',
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String title;
  final ConversationKind kind;
  final int messageCount;
  final bool isActive;
  final DateTime updatedAt;

  String get category =>
      kind == ConversationKind.roleplay ? 'Roleplay' : 'Free chat';

  String get preview {
    final String messageLabel = messageCount == 1 ? 'message' : 'messages';
    final String statusLabel = isActive ? 'Continue speaking' : 'Completed';
    return '$messageCount $messageLabel · $statusLabel';
  }
}
