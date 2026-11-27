import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter/material.dart';

String snackRegisterLabel(String label, bool korean) {
  if (!korean) return label;
  return switch (label.toLowerCase()) {
    'formal' => '격식 있는 표현',
    'informal' => '일상적인 표현',
    'polite' => '정중한 표현',
    'casual' => '편한 표현',
    _ => label,
  };
}

class LanguageSnackContent extends StatelessWidget {
  const LanguageSnackContent({required this.snack, super.key});
  final LanguageSnack snack;

  @override
  Widget build(BuildContext context) {
    final korean = snack.explanationLanguage == 'ko';
    final idiom = snack.payload is IdiomaticPayload;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(16) <= 21 &&
            snack.items.every((item) => item.expression.runes.length <= 18);
        final cores = snack.items
            .map(
              (item) => _Core(
                item: item,
                label: item.label == null
                    ? null
                    : snack.contentType == 'register_contrast'
                    ? snackRegisterLabel(item.label!, korean)
                    : item.label,
              ),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snack.payload case RegisterPayload(:final situation)) ...[
              Text(situation, style: AppTypography.bodySm),
              const SizedBox(height: AppSpacing.md),
            ],
            if (snack.payload case CollocationPayload(:final headword)) ...[
              Text(
                '${korean ? '중심 단어' : 'Headword'} · $headword',
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (snack.meaning != null) ...[
              Text(snack.meaning!, style: AppTypography.bodySm),
              const SizedBox(height: AppSpacing.md),
            ],
            if (cores.length == 2 && sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cores[0]),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: cores[1]),
                ],
              )
            else
              ...cores.expand(
                (core) => [core, const SizedBox(height: AppSpacing.md)],
              ),
            if (snack.items.any((item) => item.example != null)) ...[
              const Divider(height: 24),
              Text(
                korean ? '이렇게 써요' : 'In conversation',
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final item in snack.items)
                if (item.example != null) ...[
                  if (!idiom) Text(item.expression, style: AppTypography.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.example!, style: AppTypography.bodySm),
                  if (item.exampleTranslation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.exampleTranslation!,
                      style: AppTypography.bodySm.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
            ],
            if (snack.payload case IdiomaticPayload(
              :final item,
              :final literalMeaning,
            )) ...[
              Text(
                korean ? '언제 쓰나요?' : 'When to use it',
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(item.usage!, style: AppTypography.bodySm),
              const SizedBox(height: AppSpacing.md),
              Text(
                korean ? '말 그대로 풀면' : 'Literally',
                style: AppTypography.label,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(literalMeaning, style: AppTypography.bodySm),
            ],
          ],
        );
      },
    );
  }
}

class _Core extends StatelessWidget {
  const _Core({required this.item, this.label});
  final SnackExpression item;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(item.expression, style: AppTypography.headlineMd),
        if (item.meaning ?? item.usage case final String detail) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(detail, style: AppTypography.bodySm),
        ],
      ],
    ),
  );
}
