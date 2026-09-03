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
    this.onAutoPlayStarted,
    super.key,
  });

  final ConversationMessage message;
  final bool autoPlayAudio;
  final VoidCallback? onAutoPlayStarted;

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
          footer: !isUser && message.audio != null
              ? _AssistantAudioSlot(
                  message: message,
                  autoPlayAudio: autoPlayAudio,
                  onAutoPlayStarted: onAutoPlayStarted,
                )
              : null,
        ),
        if (isUser && !message.isLocalPending) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _GrammarFeedbackSlot(message: message),
        ],
        if (!isUser && message.audioError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _FeedbackStatusText(
            label: AppCopy.of(
              context,
            ).failureMessage('assistantAudioUnavailable'),
          ),
        ],
      ],
    );
  }
}

class _AssistantAudioSlot extends ConsumerStatefulWidget {
  const _AssistantAudioSlot({
    required this.message,
    required this.autoPlayAudio,
    this.onAutoPlayStarted,
  });

  final ConversationMessage message;
  final bool autoPlayAudio;
  final VoidCallback? onAutoPlayStarted;

  @override
  ConsumerState<_AssistantAudioSlot> createState() =>
      _AssistantAudioSlotState();
}

class _AssistantAudioSlotState extends ConsumerState<_AssistantAudioSlot> {
  _AssistantAudioPhase _phase = _AssistantAudioPhase.idle;
  bool _autoPlayStarted = false;

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
      _autoPlayStarted = false;
    }
    _scheduleAutoPlayIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceAudioResponse? audio = widget.message.audio;
    if (audio == null) {
      return const SizedBox.shrink();
    }

    final bool isBusy =
        _phase == _AssistantAudioPhase.loading ||
        _phase == _AssistantAudioPhase.playing;
    final AppCopy copy = AppCopy.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Tooltip(
        message: isBusy ? copy.stopAudioResponseLabel : copy.audioReplayLabel,
        child: IconButton(
          onPressed: isBusy ? _stop : () => _play(audio),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.blockLime,
            foregroundColor: AppPalette.ink,
            minimumSize: const Size.square(32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(isBusy ? Icons.stop_rounded : Icons.volume_up_rounded),
        ),
      ),
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
        widget.onAutoPlayStarted?.call();
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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppCopy.of(context).failureMessage(error.reason.name),
            ),
          ),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (_phase != _AssistantAudioPhase.loading &&
        _phase != _AssistantAudioPhase.playing) {
      return;
    }
    try {
      await ref.read(conversationAudioPlayerProvider).stop();
    } on ConversationAudioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppCopy.of(context).failureMessage(error.reason.name),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _phase = _AssistantAudioPhase.idle);
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
        label: AppCopy.of(
          context,
        ).failureMessage(state.failureReason?.name ?? 'grammarRequestFailed'),
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
      return const NaturalFeedbackBadge();
    }

    return _ExpandableGrammarFeedback(feedback: feedback);
  }
}

class _ExpandableGrammarFeedback extends StatefulWidget {
  const _ExpandableGrammarFeedback({required this.feedback});

  final GrammarFeedback feedback;

  @override
  State<_ExpandableGrammarFeedback> createState() =>
      _ExpandableGrammarFeedbackState();
}

class _ExpandableGrammarFeedbackState
    extends State<_ExpandableGrammarFeedback> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final String tooltip = _expanded
        ? copy.hideGrammarFeedbackLabel
        : copy.showGrammarFeedbackLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            label: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _expanded = !_expanded);
              },
              child: const SizedBox(
                width: AppSize.touchTarget,
                height: AppSize.touchTarget,
                child: Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppPalette.semanticError,
                    size: AppSize.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          GrammarFeedbackCard(
            suggestion: widget.feedback.correctedText,
            explanation: widget.feedback.explanation,
            errors: widget.feedback.errors,
          ),
        ],
      ],
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
