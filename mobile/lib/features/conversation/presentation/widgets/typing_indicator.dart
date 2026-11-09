import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({this.semanticLabel, super.key});

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel ?? AppCopy.of(context).typingSemanticLabel,
      child: const ExcludeSemantics(
        child: Align(
          alignment: Alignment.center,
          child: AppLoadingIndicator(
            key: ValueKey<String>('conversation-reply-tomato-loading'),
            width: 120,
          ),
        ),
      ),
    );
  }
}
