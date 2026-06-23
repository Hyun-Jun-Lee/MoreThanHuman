import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      AppSpacing.screenPadding,
      AppSpacing.md,
    ),
    super.key,
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
