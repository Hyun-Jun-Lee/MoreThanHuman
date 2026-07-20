import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppParagraphText extends StatelessWidget {
  const AppParagraphText({
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
    this.paragraphSpacing = AppSpacing.sm,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.semanticLabel,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final double paragraphSpacing;
  final int? maxLines;
  final TextOverflow overflow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final List<String> paragraphs = _paragraphs;
    if (paragraphs.length == 1) {
      return Text(
        paragraphs.single,
        maxLines: maxLines,
        overflow: overflow,
        semanticsLabel: semanticLabel,
        style: style,
        textAlign: textAlign,
      );
    }

    return Semantics(
      label: semanticLabel ?? paragraphs.join('\n\n'),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: _crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < paragraphs.length; index++) ...<Widget>[
              Text(
                paragraphs[index],
                maxLines: maxLines,
                overflow: overflow,
                style: style,
                textAlign: textAlign,
              ),
              if (index != paragraphs.length - 1)
                SizedBox(height: paragraphSpacing),
            ],
          ],
        ),
      ),
    );
  }

  List<String> get _paragraphs {
    final String normalized = text.trim();
    if (normalized.isEmpty) {
      return <String>[''];
    }
    return normalized
        .split(RegExp(r'\n\s*\n'))
        .map((String paragraph) => paragraph.trim())
        .where((String paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
  }

  CrossAxisAlignment get _crossAxisAlignment {
    return switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
  }
}
