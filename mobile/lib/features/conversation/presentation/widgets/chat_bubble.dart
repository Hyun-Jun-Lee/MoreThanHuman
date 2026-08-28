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
    super.key,
  });

  final String message;
  final ChatSpeaker speaker;
  final Widget? footer;
  final String? semanticLabel;

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
                      AppParagraphText(
                        text: displayMessage,
                        style: AppTypography.bodySm.copyWith(
                          color: foregroundColor,
                        ),
                      ),
                      if (footer != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: footer!,
                        ),
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
