import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/app_color_block_card.dart';
import 'package:flutter/material.dart';

class RecentConversationCard extends StatelessWidget {
  const RecentConversationCard({
    required this.category,
    required this.title,
    required this.preview,
    required this.color,
    required this.onTap,
    this.onDelete,
    super.key,
  });

  final String category;
  final String title;
  final String preview;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AppColorBlockCard(
      color: color,
      onTap: onTap,
      semanticLabel: AppCopy.of(
        context,
      ).recentConversationSemanticLabel(category, title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: AppCopy.of(context).deleteConversationTooltip,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onDelete,
                ),
            ],
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
