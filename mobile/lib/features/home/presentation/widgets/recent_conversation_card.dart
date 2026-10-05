import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/app_color_block_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class RecentConversationCard extends StatefulWidget {
  const RecentConversationCard({
    required this.category,
    required this.title,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.onDelete,
    super.key,
  });

  final String category;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  State<RecentConversationCard> createState() => _RecentConversationCardState();
}

class _RecentConversationCardState extends State<RecentConversationCard> {
  static const double _deleteWidth = 88;
  double _dragOffset = 0;
  bool _dragging = false;

  void _close() => setState(() => _dragOffset = 0);

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_deleteWidth, 0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldReveal =
        velocity < -250 || (velocity <= 250 && _dragOffset < -_deleteWidth / 2);
    setState(() {
      _dragging = false;
      _dragOffset = shouldReveal ? -_deleteWidth : 0;
    });
  }

  void _delete() {
    _close();
    widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    if (widget.onDelete == null) return _card(context, copy);

    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: copy.deleteLabel): _delete,
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _deleteWidth,
                      child: ExcludeSemantics(
                        excluding: _dragOffset != -_deleteWidth,
                        child: Center(
                          child: TextButton(
                            onPressed: _dragOffset == -_deleteWidth
                                ? _delete
                                : null,
                            child: Text(copy.deleteLabel),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                onHorizontalDragCancel: () {
                  setState(() {
                    _dragging = false;
                    _dragOffset = 0;
                  });
                },
                child: AnimatedSlide(
                  offset: Offset(_dragOffset / constraints.maxWidth, 0),
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: _card(context, copy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AppCopy copy) {
    return AppColorBlockCard(
      color: widget.color,
      onTap: _dragOffset < 0 ? _close : widget.onTap,
      semanticLabel: copy.recentConversationSemanticLabel(
        widget.category,
        widget.title,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMd.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppPalette.canvas,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.full),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        widget.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono.copyWith(
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
