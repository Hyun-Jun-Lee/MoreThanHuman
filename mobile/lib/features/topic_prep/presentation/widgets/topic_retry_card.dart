import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/app_color_block_card.dart';
import 'package:curitalk/core/widgets/app_primary_button.dart';
import 'package:flutter/material.dart';

class TopicRetryCard extends StatelessWidget {
  const TopicRetryCard({
    required this.message,
    required this.onEditTopic,
    required this.onTryAnotherIdea,
    this.title = 'We need a clearer topic',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onEditTopic;
  final VoidCallback onTryAnotherIdea;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors colors = AppSemanticColors.of(context);

    return AppColorBlockCard(
      color: colors.searchRetrySurface,
      child: Column(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.onSearchRetry,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Icon(
                Icons.priority_high_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: AppSize.icon,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMd.copyWith(
              color: colors.onSearchRetry,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: colors.onSearchRetry),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(label: 'Edit topic', onPressed: onEditTopic),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTryAnotherIdea,
              child: const Text('Try another idea'),
            ),
          ),
        ],
      ),
    );
  }
}
