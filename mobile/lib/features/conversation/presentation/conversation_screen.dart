import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/application/conversation_audio_services.dart';
import 'package:curitalk/features/conversation/application/conversation_controller.dart';
import 'package:curitalk/features/conversation/domain/conversation_models.dart';
import 'package:curitalk/features/conversation/domain/conversation_repository.dart';
import 'package:curitalk/features/conversation/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  late final TextEditingController _composerController;
  late final ConversationAudioRecorder _recorder;
  Timer? _recordingTimer;
  _VoiceInputState _voiceInput = const _VoiceInputState.idle();

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _recorder = ref.read(conversationAudioRecorderProvider);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_voiceInput.isRecordingActive) {
      unawaited(_recorder.cancel());
    }
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ConversationState> conversation = ref.watch(
      conversationControllerProvider(widget.conversationId),
    );
    final AppCopy copy = AppCopy.of(context);
    final bool isSending = conversation.value?.isSending == true;

    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: copy.backToHomeLabel,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        title: Text(copy.conversationTitle),
      ),
      bottomNavigationBar: AppBottomActionBar(
        child: ChatComposer(
          controller: _composerController,
          enabled: conversation.hasValue,
          isSending: isSending,
          isRecording: _voiceInput.phase == _VoiceInputPhase.recording,
          isVoiceBusy: _voiceInput.isBusy,
          recordingElapsedText: _voiceInput.phase == _VoiceInputPhase.recording
              ? _formatElapsed(_voiceInput.elapsed)
              : null,
          voiceStatusLabel: _voiceInput.statusLabel(copy),
          onSend: _sendMessage,
          onVoiceInput: _toggleVoiceInput,
          onCancelVoiceInput: _voiceInput.isRecordingActive
              ? _cancelVoiceInput
              : null,
        ),
      ),
      body: conversation.when(
        loading: () => AppAsyncStateView.loading(message: copy.loadingMessages),
        error: (_, _) => AppAsyncStateView.error(
          title: copy.loadConversationFailedTitle,
          message: copy.connectionRetryMessage,
          onRetry: () => ref
              .read(
                conversationControllerProvider(widget.conversationId).notifier,
              )
              .reload(),
        ),
        data: (ConversationState state) => _ConversationMessageList(
          conversationId: widget.conversationId,
          state: state,
          voiceFailureReason: _voiceInput.failureReason,
        ),
      ),
    );
  }

  void _sendMessage(String message) {
    _composerController.clear();
    unawaited(
      ref
          .read(conversationControllerProvider(widget.conversationId).notifier)
          .send(message),
    );
  }

  Future<void> _toggleVoiceInput() async {
    final ConversationController controller = ref.read(
      conversationControllerProvider(widget.conversationId).notifier,
    );
    if (_voiceInput.phase == _VoiceInputPhase.idle ||
        _voiceInput.phase == _VoiceInputPhase.failed ||
        _voiceInput.phase == _VoiceInputPhase.permissionDenied) {
      try {
        setState(() => _voiceInput = const _VoiceInputState.starting());
        await _recorder.start();
        if (!mounted) {
          return;
        }
        _startRecordingTimer();
        setState(() {
          _voiceInput = const _VoiceInputState.recording();
        });
      } on ConversationAudioException catch (error) {
        if (mounted) {
          _stopRecordingTimer();
          setState(
            () => _voiceInput =
                error.reason ==
                    ConversationAudioExceptionReason.permissionDenied
                ? _VoiceInputState.permissionDenied(error.reason)
                : _VoiceInputState.failed(error.reason),
          );
        }
      }
      return;
    }

    if (_voiceInput.phase != _VoiceInputPhase.recording) {
      return;
    }

    try {
      final Duration recordingElapsed = _voiceInput.elapsed;
      _stopRecordingTimer();
      setState(() => _voiceInput = const _VoiceInputState.stopping());
      final ConversationAudioFile audioFile = await _recorder.stop();
      if (!mounted) {
        return;
      }
      if (recordingElapsed < minimumVoiceRecordingDuration) {
        throw const ConversationAudioException(
          voiceNotRecognizedMessage,
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      if (audioFile.bytes.isEmpty) {
        throw const ConversationAudioException(
          'Recording did not produce audio.',
          reason: ConversationAudioExceptionReason.emptyRecording,
        );
      }
      setState(() => _voiceInput = const _VoiceInputState.sending());
      await controller.sendAudio(audioFile);
      if (mounted) {
        setState(() => _voiceInput = const _VoiceInputState.idle());
      }
    } on ConversationAudioException catch (error) {
      if (mounted) {
        _stopRecordingTimer();
        setState(() {
          _voiceInput = _VoiceInputState.failed(error.reason);
        });
      }
    }
  }

  Future<void> _cancelVoiceInput() async {
    if (!_voiceInput.isRecordingActive) {
      return;
    }
    _stopRecordingTimer();
    try {
      await _recorder.cancel();
    } on Object {
      // The user intent is still to leave the recording state.
    }
    if (mounted) {
      setState(() => _voiceInput = const _VoiceInputState.idle());
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(voiceRecordingTimerTick, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _voiceInput = _voiceInput.copyWith(
          elapsed: _voiceInput.elapsed + voiceRecordingTimerTick,
        );
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  String _formatElapsed(Duration elapsed) {
    final int minutes = elapsed.inMinutes;
    final int seconds = elapsed.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _goBack() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(AppRoute.home);
  }
}

enum _VoiceInputPhase {
  idle,
  starting,
  recording,
  stopping,
  sending,
  failed,
  permissionDenied,
}

class _VoiceInputState {
  const _VoiceInputState._({
    required this.phase,
    this.elapsed = Duration.zero,
    this.failureReason,
  });

  const _VoiceInputState.idle() : this._(phase: _VoiceInputPhase.idle);

  const _VoiceInputState.starting() : this._(phase: _VoiceInputPhase.starting);

  const _VoiceInputState.recording({Duration elapsed = Duration.zero})
    : this._(phase: _VoiceInputPhase.recording, elapsed: elapsed);

  const _VoiceInputState.stopping() : this._(phase: _VoiceInputPhase.stopping);

  const _VoiceInputState.sending() : this._(phase: _VoiceInputPhase.sending);

  const _VoiceInputState.failed(ConversationAudioExceptionReason reason)
    : this._(phase: _VoiceInputPhase.failed, failureReason: reason);

  const _VoiceInputState.permissionDenied(
    ConversationAudioExceptionReason reason,
  ) : this._(phase: _VoiceInputPhase.permissionDenied, failureReason: reason);

  final _VoiceInputPhase phase;
  final Duration elapsed;
  final ConversationAudioExceptionReason? failureReason;

  bool get isBusy =>
      phase == _VoiceInputPhase.starting ||
      phase == _VoiceInputPhase.stopping ||
      phase == _VoiceInputPhase.sending;

  bool get isRecordingActive =>
      phase == _VoiceInputPhase.starting ||
      phase == _VoiceInputPhase.recording ||
      phase == _VoiceInputPhase.stopping;

  String? statusLabel(AppCopy copy) {
    return switch (phase) {
      _VoiceInputPhase.starting => copy.voiceStatus('starting'),
      _VoiceInputPhase.recording => copy.voiceStatus('recording'),
      _VoiceInputPhase.stopping => copy.voiceStatus('stopping'),
      _VoiceInputPhase.sending => copy.voiceStatus('sending'),
      _ => null,
    };
  }

  _VoiceInputState copyWith({Duration? elapsed}) {
    return _VoiceInputState._(
      phase: phase,
      elapsed: elapsed ?? this.elapsed,
      failureReason: failureReason,
    );
  }
}

class _ConversationMessageList extends ConsumerWidget {
  const _ConversationMessageList({
    required this.conversationId,
    required this.state,
    this.voiceFailureReason,
  });

  final String conversationId;
  final ConversationState state;
  final ConversationAudioExceptionReason? voiceFailureReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.messages.isEmpty &&
        state.failedMessage == null &&
        state.failedAudioFile == null &&
        state.failureReason == null &&
        !state.isSending) {
      final AppCopy copy = AppCopy.of(context);
      return AppAsyncStateView.empty(
        title: copy.noMessagesTitle,
        message: copy.noMessagesMessage,
      );
    }

    final List<Widget> children = <Widget>[
      const SizedBox(height: AppSpacing.lg),
      for (final ConversationMessage message in state.messages) ...<Widget>[
        ConversationMessageTile(
          key: ValueKey(message.id),
          message: message,
          autoPlayAudio: state.autoPlayAudioMessageIds.contains(message.id),
          onAutoPlayStarted: () => ref
              .read(conversationControllerProvider(conversationId).notifier)
              .consumeAutoPlayAudio(message.id),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.isSending) ...<Widget>[
        const TypingIndicator(),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.failedMessage != null || state.failureReason != null)
        _SendFailureCard(
          reason:
              state.failureReason ??
              ConversationSendFailureReason.textRequestFailed,
          onRetry: () {
            final ConversationController controller = ref.read(
              conversationControllerProvider(conversationId).notifier,
            );
            if (state.failedAudioFile != null) {
              controller.retryFailedAudio();
            } else {
              controller.retryFailedMessage();
            }
          },
        ),
      if (state.assistantAudioStatus != null) ...<Widget>[
        AppColorBlockCard(
          color: AppPalette.blockCream,
          child: Text(
            AppCopy.of(context).failureMessage('assistantAudioUnavailable'),
            style: AppTypography.bodySm,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (voiceFailureReason != null) ...<Widget>[
        AppColorBlockCard(
          color: AppPalette.blockPink,
          child: Text(
            AppCopy.of(context).failureMessage(voiceFailureReason!.name),
            style: AppTypography.bodySm,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.xl),
    ];

    return ListView(children: children);
  }

}

class _SendFailureCard extends StatelessWidget {
  const _SendFailureCard({required this.reason, required this.onRetry});

  final ConversationSendFailureReason reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppColorBlockCard(
      color: AppPalette.blockPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppCopy.of(context).failureMessage(reason.name),
            style: AppTypography.bodySm,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppCopy.of(context).retryLabel),
          ),
        ],
      ),
    );
  }
}
