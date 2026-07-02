import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/conversation/application/grammar_feedback_polling_controller.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';
import 'package:curitalk/features/conversation/presentation/widgets/chat_bubble.dart';
import 'package:curitalk/features/conversation/presentation/widgets/grammar_feedback_card.dart';
import 'package:curitalk/features/conversation/presentation/widgets/natural_feedback_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationMessageTile extends ConsumerWidget {
  const ConversationMessageTile({required this.message, super.key});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.role == ConversationMessageRole.system) {
      return Center(
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: AppTypography.captionMono.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final bool isUser = message.role == ConversationMessageRole.user;
    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        ChatBubble(
          message: message.content,
          speaker: isUser ? ChatSpeaker.user : ChatSpeaker.assistant,
        ),
        if (isUser && !message.isLocalPending) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _GrammarFeedbackSlot(message: message),
        ],
      ],
    );
  }
}

class _GrammarFeedbackSlot extends ConsumerWidget {
  const _GrammarFeedbackSlot({required this.message});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GrammarFeedback? completedFeedback = message.grammarFeedback;
    if (completedFeedback != null) {
      return _CompletedGrammarFeedback(feedback: completedFeedback);
    }

    final GrammarFeedbackPollingState state = ref.watch(
      grammarFeedbackPollingControllerProvider(message.id),
    );
    return switch (state.status) {
      GrammarFeedbackPollingStatus.pending => _FeedbackStatusText(
        label: 'Grammar: checking...',
        liveRegion: true,
      ),
      GrammarFeedbackPollingStatus.completed =>
        state.feedback == null
            ? const SizedBox.shrink()
            : _CompletedGrammarFeedback(feedback: state.feedback!),
      GrammarFeedbackPollingStatus.timeout => const _FeedbackStatusText(
        label: 'Grammar feedback is taking longer than usual.',
      ),
      GrammarFeedbackPollingStatus.error => _FeedbackStatusText(
        label: state.errorMessage ?? 'Grammar feedback is unavailable.',
      ),
    };
  }
}

class _CompletedGrammarFeedback extends StatelessWidget {
  const _CompletedGrammarFeedback({required this.feedback});

  final GrammarFeedback feedback;

  @override
  Widget build(BuildContext context) {
    if (!feedback.hasErrors) {
      return NaturalFeedbackBadge(onTap: () {});
    }

    return GrammarFeedbackCard(
      suggestion: feedback.correctedText,
      explanation: feedback.explanation,
    );
  }
}

class _FeedbackStatusText extends StatelessWidget {
  const _FeedbackStatusText({required this.label, this.liveRegion = false});

  final String label;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: liveRegion,
      child: Text(
        label,
        style: AppTypography.bodySm.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
