import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

class NaturalFeedbackBadge extends StatelessWidget {
  const NaturalFeedbackBadge({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final String semanticLabel = label ?? AppCopy.of(context).looksNaturalLabel;

    return Tooltip(
      message: semanticLabel,
      child: Icon(
        Icons.check_circle_rounded,
        semanticLabel: semanticLabel,
        color: AppPalette.semanticSuccess,
        size: AppSize.icon,
      ),
    );
  }
}
