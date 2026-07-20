import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/conversation/application/conversation_audio_services.dart';
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
        if (!isUser &&
            (message.audio != null || message.audioError != null)) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _AssistantAudioSlot(message: message),
        ],
      ],
    );
  }
}

class _AssistantAudioSlot extends ConsumerStatefulWidget {
  const _AssistantAudioSlot({required this.message});

  final ConversationMessage message;

  @override
  ConsumerState<_AssistantAudioSlot> createState() =>
      _AssistantAudioSlotState();
}

class _AssistantAudioSlotState extends ConsumerState<_AssistantAudioSlot> {
  _AssistantAudioPhase _phase = _AssistantAudioPhase.idle;
  String? _playbackError;

  @override
  void didUpdateWidget(covariant _AssistantAudioSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_audioIdentity(oldWidget.message) != _audioIdentity(widget.message)) {
      _phase = _AssistantAudioPhase.idle;
      _playbackError = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoiceAudioError? audioError = widget.message.audioError;
    if (audioError != null) {
      return _FeedbackStatusText(label: audioError.message);
    }

    final VoiceAudioResponse? audio = widget.message.audio;
    if (audio == null) {
      return const SizedBox.shrink();
    }

    final bool isBusy =
        _phase == _AssistantAudioPhase.loading ||
        _phase == _AssistantAudioPhase.playing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : () => _play(audio),
            icon: _phase == _AssistantAudioPhase.loading
                ? SizedBox.square(
                    dimension: AppSize.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppBorderWidth.focused,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    _phase == _AssistantAudioPhase.playing
                        ? Icons.graphic_eq_rounded
                        : Icons.volume_up_rounded,
                  ),
            label: Text(switch (_phase) {
              _AssistantAudioPhase.loading => 'Loading audio',
              _AssistantAudioPhase.playing => 'Playing response',
              _ => 'Play response',
            }),
          ),
        ),
        if (_playbackError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          _FeedbackStatusText(label: _playbackError!),
        ],
      ],
    );
  }

  Future<void> _play(VoiceAudioResponse audio) async {
    setState(() {
      _phase = _AssistantAudioPhase.loading;
      _playbackError = null;
    });
    try {
      final Future<void> playFuture = ref
          .read(conversationAudioPlayerProvider)
          .play(audio);
      if (!mounted) {
        return;
      }
      setState(() => _phase = _AssistantAudioPhase.playing);
      await playFuture;
      if (mounted) {
        setState(() => _phase = _AssistantAudioPhase.idle);
      }
    } on ConversationAudioException catch (error) {
      if (mounted) {
        setState(() {
          _phase = _AssistantAudioPhase.error;
          _playbackError = error.message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  String _audioIdentity(ConversationMessage message) {
    final VoiceAudioResponse? audio = message.audio;
    return '${message.id}:${audio?.contentType}:${audio?.format}:${audio?.base64.hashCode}:${message.audioError?.message}';
  }
}

enum _AssistantAudioPhase { idle, loading, playing, error }

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
