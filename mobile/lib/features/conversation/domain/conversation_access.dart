class ConversationAccess {
  const ConversationAccess({
    required this.enabled,
    required this.canCreate,
    required this.usedSlots,
    this.slotLimit,
    this.remainingSlots,
    this.lockedCount = 0,
    this.plan = 'free',
    this.activeConversations = const [],
  });

  const ConversationAccess.disabled()
    : enabled = false,
      canCreate = true,
      usedSlots = 0,
      slotLimit = null,
      remainingSlots = null,
      lockedCount = 0,
      plan = 'free',
      activeConversations = const [];

  factory ConversationAccess.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['enabled'] is! bool ||
        value['can_create'] is! bool ||
        value['used_slots'] is! int) {
      throw const FormatException('Conversation access payload is invalid.');
    }
    return ConversationAccess(
      enabled: value['enabled'] as bool,
      canCreate: value['can_create'] as bool,
      usedSlots: value['used_slots'] as int,
      slotLimit: value['slot_limit'] as int?,
      remainingSlots: value['remaining_slots'] as int?,
      lockedCount: value['locked_count'] as int? ?? 0,
      plan: value['plan'] as String? ?? 'free',
      activeConversations:
          (value['active_conversations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => ActiveConversation(
                  id: item['id'] as String,
                  title: item['title'] as String,
                ),
              )
              .toList(),
    );
  }

  final bool enabled;
  final bool canCreate;
  final int usedSlots;
  final int? slotLimit;
  final int? remainingSlots;
  final int lockedCount;
  final String plan;
  final List<ActiveConversation> activeConversations;

  bool get isLocked => enabled && !canCreate;
}

class ActiveConversation {
  const ActiveConversation({required this.id, required this.title});
  final String id;
  final String title;
}

class ConversationTurnAccess {
  const ConversationTurnAccess({
    required this.enabled,
    required this.userTurns,
    required this.canSend,
    this.turnLimit,
    this.locked = false,
  });

  const ConversationTurnAccess.disabled()
    : enabled = false,
      userTurns = 0,
      canSend = true,
      turnLimit = null,
      locked = false;

  factory ConversationTurnAccess.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['enabled'] is! bool ||
        value['user_turns'] is! int ||
        value['can_send'] is! bool) {
      throw const FormatException(
        'Conversation turn access payload is invalid.',
      );
    }
    return ConversationTurnAccess(
      enabled: value['enabled'] as bool,
      userTurns: value['user_turns'] as int,
      canSend: value['can_send'] as bool,
      turnLimit: value['turn_limit'] as int?,
      locked: value['locked'] as bool? ?? false,
    );
  }

  final bool enabled;
  final int userTurns;
  final int? turnLimit;
  final bool canSend;
  final bool locked;
}
