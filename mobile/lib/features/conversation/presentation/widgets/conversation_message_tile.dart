import 'dart:async';

import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
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
  const ConversationMessageTile({
    required this.message,
    this.autoPlayAudio = false,
    super.key,
  });

  final ConversationMessage message;
  final bool autoPlayAudio;

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
          _AssistantAudioSlot(message: message, autoPlayAudio: autoPlayAudio),
        ],
      ],
    );
  }
}

class _AssistantAudioSlot extends ConsumerStatefulWidget {
  const _AssistantAudioSlot({
    required this.message,
    required this.autoPlayAudio,
  });

  final ConversationMessage message;
  final bool autoPlayAudio;

  @override
  ConsumerState<_AssistantAudioSlot> createState() =>
      _AssistantAudioSlotState();
}

class _AssistantAudioSlotState extends ConsumerState<_AssistantAudioSlot> {
  _AssistantAudioPhase _phase = _AssistantAudioPhase.idle;
  ConversationAudioExceptionReason? _playbackFailureReason;
  bool _autoPlayStarted = false;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoPlayIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AssistantAudioSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_audioIdentity(oldWidget.message) != _audioIdentity(widget.message)) {
      _phase = _AssistantAudioPhase.idle;
      _playbackFailureReason = null;
      _autoPlayStarted = false;
      _hasPlayed = false;
    }
    _scheduleAutoPlayIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.audioError != null) {
      return _FeedbackStatusText(
        label: AppCopy.of(context).failureMessage('assistantAudioUnavailable'),
      );
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
              _AssistantAudioPhase.loading => AppCopy.of(context).audioLoadingLabel,
              _AssistantAudioPhase.playing => AppCopy.of(context).audioPlayingLabel,
              _ => _hasPlayed
                  ? AppCopy.of(context).audioReplayLabel
                  : AppCopy.of(context).audioPlayLabel,
            }),
          ),
        ),
        if (_playbackFailureReason != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          _FeedbackStatusText(
            label: AppCopy.of(context).failureMessage(
              _playbackFailureReason!.name,
            ),
          ),
        ],
      ],
    );
  }

  void _scheduleAutoPlayIfNeeded() {
    if (!widget.autoPlayAudio || _autoPlayStarted) {
      return;
    }
    final VoiceAudioResponse? audio = widget.message.audio;
    if (audio == null) {
      return;
    }
    _autoPlayStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_play(audio));
      }
    });
  }

  Future<void> _play(VoiceAudioResponse audio) async {
    if (_phase == _AssistantAudioPhase.loading ||
        _phase == _AssistantAudioPhase.playing) {
      return;
    }
    setState(() {
      _phase = _AssistantAudioPhase.loading;
      _playbackFailureReason = null;
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
        setState(() {
          _phase = _AssistantAudioPhase.idle;
          _hasPlayed = true;
        });
      }
    } on ConversationAudioException catch (error) {
      if (mounted) {
        setState(() {
          _phase = _AssistantAudioPhase.error;
          _playbackFailureReason = error.reason;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              AppCopy.of(context).failureMessage(error.reason.name),
            ),
          ),
        );
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
        label: AppCopy.of(context).grammarCheckingLabel,
        liveRegion: true,
      ),
      GrammarFeedbackPollingStatus.completed =>
        state.feedback == null
            ? const SizedBox.shrink()
            : _CompletedGrammarFeedback(feedback: state.feedback!),
      GrammarFeedbackPollingStatus.timeout => _FeedbackStatusText(
        label: AppCopy.of(context).grammarDelayedLabel,
      ),
      GrammarFeedbackPollingStatus.error => _FeedbackStatusText(
        label: AppCopy.of(context).failureMessage(
          state.failureReason?.name ?? 'grammarRequestFailed',
        ),
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
      errors: feedback.errors,
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
