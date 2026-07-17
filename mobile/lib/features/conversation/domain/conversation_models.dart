import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';

enum ConversationType {
  freeChat('FREE_CHAT'),
  rolePlaying('ROLE_PLAYING');

  const ConversationType(this.value);

  final String value;

  static ConversationType fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('Conversation type is invalid.');
    }
    return ConversationType.values.firstWhere(
      (ConversationType type) => type.value == value,
      orElse: () {
        throw const FormatException('Conversation type is invalid.');
      },
    );
  }
}

enum ConversationMessageRole {
  user('user'),
  assistant('assistant'),
  system('system');

  const ConversationMessageRole(this.value);

  final String value;

  static ConversationMessageRole fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('Conversation message role is invalid.');
    }
    return ConversationMessageRole.values.firstWhere(
      (ConversationMessageRole role) => role.value == value,
      orElse: () {
        throw const FormatException('Conversation message role is invalid.');
      },
    );
  }
}

enum ConversationInputMode {
  text('text'),
  audio('audio');

  const ConversationInputMode(this.value);

  final String value;

  static ConversationInputMode fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('Conversation input mode is invalid.');
    }
    return ConversationInputMode.values.firstWhere(
      (ConversationInputMode mode) => mode.value == value,
      orElse: () {
        throw const FormatException('Conversation input mode is invalid.');
      },
    );
  }
}

class VoiceAudioResponse {
  const VoiceAudioResponse({
    required this.contentType,
    required this.base64,
    required this.format,
  });

  factory VoiceAudioResponse.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Voice audio response must be an object.');
    }

    final Object? contentType = json['content_type'];
    final Object? base64 = json['base64'];
    final Object? format = json['format'];
    if (contentType is! String ||
        contentType.isEmpty ||
        base64 is! String ||
        base64.isEmpty ||
        format is! String ||
        format.isEmpty) {
      throw const FormatException('Voice audio response payload is invalid.');
    }

    return VoiceAudioResponse(
      contentType: contentType,
      base64: base64,
      format: format,
    );
  }

  final String contentType;
  final String base64;
  final String format;
}

class VoiceAudioError {
  const VoiceAudioError({required this.message, this.provider});

  factory VoiceAudioError.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Voice audio error must be an object.');
    }

    final Object? message = json['message'];
    final Object? provider = json['provider'];
    if (message is! String ||
        message.isEmpty ||
        (provider != null && provider is! String)) {
      throw const FormatException('Voice audio error payload is invalid.');
    }

    return VoiceAudioError(message: message, provider: provider as String?);
  }

  final String message;
  final String? provider;
}

class ConversationResponse {
  const ConversationResponse({
    required this.conversationId,
    required this.messageId,
    required this.conversationType,
    required this.response,
    this.roleCharacter,
    this.grammarFeedback,
  });

  factory ConversationResponse.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Conversation response must be a JSON object.',
      );
    }

    final Object? conversationId = json['conversation_id'];
    final Object? messageId = json['message_id'];
    final Object? response = json['response'];
    final Object? roleCharacter = json['role_character'];
    if (conversationId is! String ||
        conversationId.isEmpty ||
        messageId is! String ||
        messageId.isEmpty ||
        response is! String ||
        (roleCharacter != null && roleCharacter is! String)) {
      throw const FormatException('Conversation response payload is invalid.');
    }

    return ConversationResponse(
      conversationId: conversationId,
      messageId: messageId,
      conversationType: ConversationType.fromJson(json['conversation_type']),
      roleCharacter: roleCharacter as String?,
      response: response,
      grammarFeedback: json['grammar_feedback'] == null
          ? null
          : GrammarFeedback.fromJson(json['grammar_feedback']),
    );
  }

  final String conversationId;
  final String messageId;
  final ConversationType conversationType;
  final String? roleCharacter;
  final String response;
  final GrammarFeedback? grammarFeedback;
}

class MultimodalConversationResponse extends ConversationResponse {
  const MultimodalConversationResponse({
    required super.conversationId,
    required super.messageId,
    required super.conversationType,
    required super.response,
    required this.inputMode,
    super.roleCharacter,
    super.grammarFeedback,
    this.transcript,
    this.audio,
    this.audioError,
  });

  factory MultimodalConversationResponse.fromJson(Object? json) {
    final ConversationResponse response = ConversationResponse.fromJson(json);
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Multimodal conversation response must be a JSON object.',
      );
    }
    return MultimodalConversationResponse(
      conversationId: response.conversationId,
      messageId: response.messageId,
      conversationType: response.conversationType,
      roleCharacter: response.roleCharacter,
      response: response.response,
      grammarFeedback: response.grammarFeedback,
      inputMode: ConversationInputMode.fromJson(
        json['input_mode'] ?? ConversationInputMode.text.value,
      ),
      transcript: _optionalString(json['transcript'], 'transcript'),
      audio: json['audio'] == null
          ? null
          : VoiceAudioResponse.fromJson(json['audio']),
      audioError: json['audio_error'] == null
          ? null
          : VoiceAudioError.fromJson(json['audio_error']),
    );
  }

  final ConversationInputMode inputMode;
  final String? transcript;
  final VoiceAudioResponse? audio;
  final VoiceAudioError? audioError;
}

class MessageResponse {
  const MessageResponse({
    required this.messageId,
    required this.response,
    required this.turnCount,
    this.grammarFeedback,
  });

  factory MessageResponse.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Message response must be a JSON object.');
    }

    final Object? messageId = json['message_id'];
    final Object? response = json['response'];
    final Object? turnCount = json['turn_count'];
    if (messageId is! String ||
        messageId.isEmpty ||
        response is! String ||
        turnCount is! int ||
        turnCount < 0) {
      throw const FormatException('Message response payload is invalid.');
    }

    return MessageResponse(
      messageId: messageId,
      response: response,
      turnCount: turnCount,
      grammarFeedback: json['grammar_feedback'] == null
          ? null
          : GrammarFeedback.fromJson(json['grammar_feedback']),
    );
  }

  final String messageId;
  final String response;
  final int turnCount;
  final GrammarFeedback? grammarFeedback;
}

class MultimodalMessageResponse extends MessageResponse {
  const MultimodalMessageResponse({
    required super.messageId,
    required super.response,
    required super.turnCount,
    required this.inputMode,
    super.grammarFeedback,
    this.transcript,
    this.audio,
    this.audioError,
  });

  factory MultimodalMessageResponse.fromJson(Object? json) {
    final MessageResponse response = MessageResponse.fromJson(json);
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Multimodal message response must be a JSON object.',
      );
    }
    return MultimodalMessageResponse(
      messageId: response.messageId,
      response: response.response,
      turnCount: response.turnCount,
      grammarFeedback: response.grammarFeedback,
      inputMode: ConversationInputMode.fromJson(
        json['input_mode'] ?? ConversationInputMode.text.value,
      ),
      transcript: _optionalString(json['transcript'], 'transcript'),
      audio: json['audio'] == null
          ? null
          : VoiceAudioResponse.fromJson(json['audio']),
      audioError: json['audio_error'] == null
          ? null
          : VoiceAudioError.fromJson(json['audio_error']),
    );
  }

  final ConversationInputMode inputMode;
  final String? transcript;
  final VoiceAudioResponse? audio;
  final VoiceAudioError? audioError;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.grammarFeedback,
    this.audio,
    this.audioError,
    this.isLocalPending = false,
  });

  factory ConversationMessage.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Conversation message must be a JSON object.',
      );
    }

    final Object? id = json['id'];
    final Object? conversationId = json['conversation_id'];
    final Object? content = json['content'];
    final DateTime? createdAt = DateTime.tryParse('${json['created_at']}');
    if (id is! String ||
        id.isEmpty ||
        conversationId is! String ||
        conversationId.isEmpty ||
        content is! String ||
        createdAt == null) {
      throw const FormatException('Conversation message payload is invalid.');
    }

    return ConversationMessage(
      id: id,
      conversationId: conversationId,
      role: ConversationMessageRole.fromJson(json['role']),
      content: content,
      createdAt: createdAt,
      grammarFeedback: json['grammar_feedback'] == null
          ? null
          : GrammarFeedback.fromJson(json['grammar_feedback']),
    );
  }

  final String id;
  final String conversationId;
  final ConversationMessageRole role;
  final String content;
  final DateTime createdAt;
  final GrammarFeedback? grammarFeedback;
  final VoiceAudioResponse? audio;
  final VoiceAudioError? audioError;
  final bool isLocalPending;

  ConversationMessage copyWith({
    String? id,
    ConversationMessageRole? role,
    String? content,
    DateTime? createdAt,
    GrammarFeedback? grammarFeedback,
    VoiceAudioResponse? audio,
    VoiceAudioError? audioError,
    bool? isLocalPending,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      grammarFeedback: grammarFeedback ?? this.grammarFeedback,
      audio: audio ?? this.audio,
      audioError: audioError ?? this.audioError,
      isLocalPending: isLocalPending ?? this.isLocalPending,
    );
  }
}

String? _optionalString(Object? value, String fieldName) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$fieldName must be a string.');
}

class PaginatedMessages {
  const PaginatedMessages({required this.results, required this.pagination});

  factory PaginatedMessages.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Message page must be a JSON object.');
    }

    final Object? results = json['results'];
    if (results is! List) {
      throw const FormatException('Message page payload is invalid.');
    }

    return PaginatedMessages(
      results: results
          .map(ConversationMessage.fromJson)
          .toList(growable: false),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }

  final List<ConversationMessage> results;
  final Pagination pagination;
}

class Pagination {
  const Pagination({
    required this.limit,
    required this.offset,
    required this.totalCount,
    required this.hasMore,
    this.nextOffset,
  });

  factory Pagination.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Pagination must be a JSON object.');
    }

    final Object? limit = json['limit'];
    final Object? offset = json['offset'];
    final Object? totalCount = json['total_count'];
    final Object? hasMore = json['has_more'];
    final Object? nextOffset = json['next_offset'];
    if (limit is! int ||
        limit < 0 ||
        offset is! int ||
        offset < 0 ||
        totalCount is! int ||
        totalCount < 0 ||
        hasMore is! bool ||
        (nextOffset != null && nextOffset is! int)) {
      throw const FormatException('Pagination payload is invalid.');
    }

    return Pagination(
      limit: limit,
      offset: offset,
      totalCount: totalCount,
      hasMore: hasMore,
      nextOffset: nextOffset as int?,
    );
  }

  final int limit;
  final int offset;
  final int totalCount;
  final bool hasMore;
  final int? nextOffset;
}
