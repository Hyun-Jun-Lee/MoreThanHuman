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
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(
                right: onDelete == null ? 0 : AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
            ),
            if (onDelete != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: AppCopy.of(context).deleteConversationTooltip,
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    minimumSize: const Size.square(28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
