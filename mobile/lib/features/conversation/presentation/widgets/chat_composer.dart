import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,
    required this.onSend,
    this.onVoiceInput,
    this.hintText = 'Type in English...',
    this.enabled = true,
    this.isSending = false,
    this.isRecording = false,
    this.isVoiceBusy = false,
    this.recordingElapsedText,
    this.voiceStatusLabel,
    this.onCancelVoiceInput,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onVoiceInput;
  final String hintText;
  final bool enabled;
  final bool isSending;
  final bool isRecording;
  final bool isVoiceBusy;
  final String? recordingElapsedText;
  final String? voiceStatusLabel;
  final VoidCallback? onCancelVoiceInput;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late bool _hasText;

  bool get _canSend =>
      widget.enabled &&
      !widget.isSending &&
      !widget.isRecording &&
      !widget.isVoiceBusy &&
      _hasText;

  @override
  void initState() {
    super.initState();
    _hasText = _containsMessage(widget.controller.text);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleTextChanged);
    _hasText = _containsMessage(widget.controller.text);
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final bool hasText = _containsMessage(widget.controller.text);
    if (hasText == _hasText) {
      return;
    }
    setState(() => _hasText = hasText);
  }

  bool _containsMessage(String value) => value.trim().isNotEmpty;

  void _send() {
    if (!_canSend) {
      return;
    }
    widget.onSend(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors colors = AppSemanticColors.of(context);
    final bool voiceEnabled =
        widget.enabled && !widget.isSending && !widget.isVoiceBusy;
    final bool showVoiceStatus =
        widget.isRecording || widget.voiceStatusLabel != null;
    final String voiceStatusText = widget.isRecording
        ? 'Recording ${widget.recordingElapsedText ?? '0:00'}'
        : widget.voiceStatusLabel ?? '';

    return Material(
      color: theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: colors.focusBorder,
          width: AppBorderWidth.focused,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (widget.onVoiceInput != null)
              IconButton(
                onPressed: voiceEnabled ? widget.onVoiceInput : null,
                tooltip: widget.isRecording
                    ? 'Stop recording'
                    : widget.voiceStatusLabel ?? 'Voice input',
                style: IconButton.styleFrom(
                  backgroundColor: widget.isRecording
                      ? colors.selectedSurface
                      : Colors.transparent,
                  foregroundColor: widget.isRecording
                      ? colors.onSelected
                      : null,
                  disabledBackgroundColor: Colors.transparent,
                ),
                icon: Icon(
                  widget.isRecording
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded,
                ),
              ),
            Expanded(
              child: showVoiceStatus
                  ? Semantics(
                      liveRegion: true,
                      label: voiceStatusText,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          voiceStatusText,
                          style: AppTypography.bodySm.copyWith(
                            color: widget.isRecording
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : TextField(
                      controller: widget.controller,
                      enabled:
                          widget.enabled &&
                          !widget.isSending &&
                          !widget.isRecording &&
                          !widget.isVoiceBusy,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
            ),
            if (widget.onCancelVoiceInput != null)
              IconButton(
                onPressed: widget.isVoiceBusy
                    ? null
                    : widget.onCancelVoiceInput,
                tooltip: 'Cancel recording',
                icon: const Icon(Icons.close_rounded),
              ),
            IconButton(
              onPressed: _canSend ? _send : null,
              tooltip: 'Send message',
              style: IconButton.styleFrom(
                backgroundColor: colors.selectedSurface,
                foregroundColor: colors.onSelected,
                disabledBackgroundColor: widget.isSending
                    ? colors.selectedSurface
                    : colors.disabledSurface,
                disabledForegroundColor: widget.isSending
                    ? colors.onSelected
                    : colors.onDisabled,
              ),
              icon: widget.isSending
                  ? SizedBox.square(
                      dimension: AppSize.icon,
                      child: CircularProgressIndicator(
                        color: colors.onSelected,
                        strokeWidth: AppBorderWidth.focused,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
