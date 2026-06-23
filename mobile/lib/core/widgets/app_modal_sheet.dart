import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return AppModalSheet(child: builder(sheetContext));
    },
  );
}

class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.screenPadding,
      AppSpacing.sm,
      AppSpacing.screenPadding,
      AppSpacing.lg,
    ),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: AppMotion.standard,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
