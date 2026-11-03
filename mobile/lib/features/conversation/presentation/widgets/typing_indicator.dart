import 'dart:math' as math;

import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({this.semanticLabel, super.key});

  final String? semanticLabel;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;

  late final AnimationController _controller = AnimationController(
    duration: AppMotion.typing,
    vsync: this,
  );
  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) {
      return;
    }

    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _controller
        ..stop()
        ..value = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticLabel ?? AppCopy.of(context).typingSemanticLabel,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.aiMessageSurface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: AppBorderWidth.hairline,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.lg),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(_dotCount, (int index) {
                      final double phase =
                          (_controller.value - index * 0.16) * 2 * math.pi;
                      final double progress = _animationsDisabled ?? false
                          ? 0.5
                          : (math.sin(phase) + 1) / 2;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == _dotCount - 1 ? 0 : AppSpacing.xxs,
                        ),
                        child: Opacity(
                          key: ValueKey<String>('typing-dot-$index'),
                          opacity: 0.35 + progress * 0.65,
                          child: Transform.translate(
                            offset: Offset(0, -AppSpacing.xxs * progress),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.onAiMessage,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(
                                dimension: AppSpacing.xs,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
