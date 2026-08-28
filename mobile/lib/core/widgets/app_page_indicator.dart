import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

class AppPageIndicator extends StatelessWidget {
  const AppPageIndicator({
    required this.count,
    required this.currentIndex,
    this.activeColor,
    this.inactiveColor,
    super.key,
  }) : assert(count > 0),
       assert(currentIndex >= 0 && currentIndex < count);

  final int count;
  final int currentIndex;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final Color resolvedActiveColor =
        activeColor ?? Theme.of(context).colorScheme.primary;
    final Color resolvedInactiveColor =
        inactiveColor ?? Theme.of(context).colorScheme.outlineVariant;

    return Semantics(
      label: AppCopy.of(context).pageLabel(currentIndex + 1, count),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(count, (int index) {
          final bool isActive = index == currentIndex;
          return AnimatedContainer(
            duration: AppMotion.standard,
            curve: Curves.easeOut,
            width: isActive ? AppSpacing.lg : AppSpacing.xs,
            height: AppSpacing.xs,
            margin: EdgeInsets.only(
              right: index == count - 1 ? 0 : AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isActive ? resolvedActiveColor : resolvedInactiveColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.full),
              ),
            ),
          );
        }),
      ),
    );
  }
}
