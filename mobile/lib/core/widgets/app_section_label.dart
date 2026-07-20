import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.label, {this.color, this.textAlign, super.key});

  final String label;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final Color foreground = color ?? Theme.of(context).colorScheme.onSurface;

    return Text(
      label.toUpperCase(),
      textAlign: textAlign,
      style: AppTypography.labelMono.copyWith(color: foreground),
    );
  }
}
