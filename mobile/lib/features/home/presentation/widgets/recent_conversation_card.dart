import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/app_color_block_card.dart';
import 'package:flutter/material.dart';

class RecentConversationCard extends StatelessWidget {
  const RecentConversationCard({
    required this.category,
    required this.title,
    required this.preview,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String category;
  final String title;
  final String preview;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppColorBlockCard(
      color: color,
      onTap: onTap,
      semanticLabel: '$category conversation: $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Chip(label: Text(category.toUpperCase())),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineMd.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
