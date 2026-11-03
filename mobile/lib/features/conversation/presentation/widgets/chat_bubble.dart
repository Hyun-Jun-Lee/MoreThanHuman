import 'dart:async';
import 'dart:math';

import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/presentation/widgets/conversation_text_formatter.dart';
import 'package:flutter/material.dart';

enum ChatSpeaker { assistant, user }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.message,
    required this.speaker,
    this.footer,
    this.semanticLabel,
    this.typing = false,
    this.minVisibleChars = 0,
    this.onVisibleChars,
    super.key,
  });

  final String message;
  final ChatSpeaker speaker;
  final Widget? footer;
  final String? semanticLabel;
  final bool typing;
  final int minVisibleChars;
  final ValueChanged<int>? onVisibleChars;

  bool get _isUser => speaker == ChatSpeaker.user;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);
    final Color backgroundColor = _isUser
        ? colors.userMessageSurface
        : colors.aiMessageSurface;
    final Color foregroundColor = _isUser
        ? colors.onUserMessage
        : colors.onAiMessage;
    final String displayMessage = _isUser
        ? message
        : ConversationTextFormatter.formatAssistantMessage(message);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Semantics(
          container: true,
          label: semanticLabel,
          excludeSemantics: semanticLabel != null,
          child: Align(
            alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: availableWidth * 0.85),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: _isUser
                      ? null
                      : Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: AppBorderWidth.hairline,
                        ),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.xl),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (typing)
                        _StreamingParagraphText(
                          rawText: message,
                          minVisibleChars: minVisibleChars,
                          onVisibleChars: onVisibleChars,
                          style: AppTypography.bodySm.copyWith(
                            color: foregroundColor,
                          ),
                        )
                      else
                        AppParagraphText(
                          text: displayMessage,
                          style: AppTypography.bodySm.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                      if (footer != null)
                        Align(alignment: Alignment.centerRight, child: footer!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreamingParagraphText extends StatefulWidget {
  const _StreamingParagraphText({
    required this.rawText,
    required this.style,
    required this.minVisibleChars,
    this.onVisibleChars,
  });

  final String rawText;
  final TextStyle style;
  final int minVisibleChars;
  final ValueChanged<int>? onVisibleChars;

  @override
  State<_StreamingParagraphText> createState() =>
      _StreamingParagraphTextState();
}

class _StreamingParagraphTextState extends State<_StreamingParagraphText> {
  static const _tick = Duration(milliseconds: 24);
  Timer? _timer;
  late List<int> _runes;
  int _visibleRunes = 0;

  @override
  void initState() {
    super.initState();
    _runes = widget.rawText.runes.toList();
    _visibleRunes = min(_runes.length, max(1, _minimumVisibleRunes()));
    _notifyAfterFrame();
    _updateTimer();
  }

  @override
  void didUpdateWidget(covariant _StreamingParagraphText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _runes = widget.rawText.runes.toList();
    _visibleRunes = min(
      _runes.length,
      max(_visibleRunes, _minimumVisibleRunes()),
    );
    _notifyAfterFrame();
    _updateTimer();
  }

  int _minimumVisibleRunes() {
    var visibleChars = 0;
    for (var index = 0; index < _runes.length; index++) {
      if (visibleChars >= widget.minVisibleChars) return index;
      visibleChars += _runes[index] > 0xFFFF ? 2 : 1;
    }
    return _runes.length;
  }

  void _updateTimer() {
    if (_visibleRunes >= _runes.length) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_tick, (_) {
      if (!mounted) return;
      final remaining = _runes.length - _visibleRunes;
      final step = remaining > 60
          ? 5
          : remaining > 20
          ? 3
          : 1;
      setState(() {
        _visibleRunes = min(_runes.length, _visibleRunes + step);
      });
      _notifyAfterFrame();
      if (_visibleRunes >= _runes.length) {
        _updateTimer();
      }
    });
  }

  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final visible = String.fromCharCodes(_runes.take(_visibleRunes));
      widget.onVisibleChars?.call(visible.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = String.fromCharCodes(_runes.take(_visibleRunes));
    return AppParagraphText(
      text: ConversationTextFormatter.formatAssistantMessage(visible),
      style: widget.style,
    );
  }
}
