import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenPadding,
    ),
    this.safeAreaTop,
    this.safeAreaBottom,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final bool? safeAreaTop;
  final bool? safeAreaBottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        top: safeAreaTop ?? appBar == null,
        bottom: safeAreaBottom ?? bottomNavigationBar == null,
        child: Padding(padding: padding, child: body),
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
