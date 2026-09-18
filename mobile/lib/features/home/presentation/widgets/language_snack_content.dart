import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter/material.dart';

class LanguageSnackContent extends StatelessWidget {
  const LanguageSnackContent({required this.snack, super.key});
  final LanguageSnack snack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            snack.contentType != 'regional_variant' ||
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 21;
        final expressions = snack.items
            .map((item) => _Expression(item: item))
            .toList();
        return SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppCopy.of(context).languageSnackTypeLabel(snack.contentType),
                style: AppTypography.captionMono,
              ),
              const SizedBox(height: AppSpacing.md),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    expressions[0],
                    const SizedBox(height: AppSpacing.lg),
                    expressions[1],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: expressions[0]),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: expressions[1]),
                  ],
                ),
              if (snack.meaning != null) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                Text(snack.meaning!, style: AppTypography.bodySm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Expression extends StatelessWidget {
  const _Expression({required this.item});
  final SnackExpression item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.label != null)
          Text(item.label!, style: AppTypography.captionMono),
        Text(item.expression, style: AppTypography.headlineMd),
        if (item.usage != null || item.meaning != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text((item.usage ?? item.meaning)!, style: AppTypography.bodySm),
        ],
        if (item.example != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.example!,
            style: AppTypography.bodySm.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        if (item.exampleTranslation != null)
          Text(item.exampleTranslation!, style: AppTypography.bodySm),
      ],
    );
  }
}
