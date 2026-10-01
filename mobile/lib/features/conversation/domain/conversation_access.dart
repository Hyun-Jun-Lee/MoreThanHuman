class ConversationAccess {
  const ConversationAccess({
    required this.enabled,
    required this.canCreate,
    required this.usedSlots,
    this.slotLimit,
    this.remainingSlots,
  });

  const ConversationAccess.disabled()
    : enabled = false,
      canCreate = true,
      usedSlots = 0,
      slotLimit = null,
      remainingSlots = null;

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
    );
  }

  final bool enabled;
  final bool canCreate;
  final int usedSlots;
  final int? slotLimit;
  final int? remainingSlots;

  bool get isLocked => enabled && !canCreate;
}

class ConversationTurnAccess {
  const ConversationTurnAccess({
    required this.enabled,
    required this.userTurns,
    required this.canSend,
    this.turnLimit,
  });

  const ConversationTurnAccess.disabled()
    : enabled = false,
      userTurns = 0,
      canSend = true,
      turnLimit = null;

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
    );
  }

  final bool enabled;
  final int userTurns;
  final int? turnLimit;
  final bool canSend;
}
