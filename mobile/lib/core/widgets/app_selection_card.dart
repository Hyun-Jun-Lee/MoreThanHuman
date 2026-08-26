import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppSelectionCard extends StatelessWidget {
  const AppSelectionCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    this.icon,
    this.trailing,
    this.surfaceColor,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final String? description;
  final Widget? icon;
  final Widget? trailing;
  final Color? surfaceColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semanticColors = AppSemanticColors.of(context);
    final bool isEnabled = onTap != null;
    final Color borderColor = selected
        ? semanticColors.focusBorder
        : theme.colorScheme.outlineVariant;
    final double borderWidth = selected
        ? AppBorderWidth.focused
        : AppBorderWidth.hairline;
    final Color contentColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: surfaceColor ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    IconTheme(
                      data: IconThemeData(
                        color: contentColor,
                        size: AppSize.icon,
                      ),
                      child: icon!,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: AppTypography.button.copyWith(
                            color: contentColor,
                          ),
                        ),
                        if (description != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            description!,
                            style: AppTypography.bodySm.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    trailing!,
                  ] else if (selected) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.check_circle_rounded,
                      color: semanticColors.selectedSurface,
                      size: AppSize.icon,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
