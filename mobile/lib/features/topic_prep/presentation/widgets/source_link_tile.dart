import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

class SourceLinkTile extends StatelessWidget {
  const SourceLinkTile({
    required this.title,
    required this.url,
    required this.onTap,
    super.key,
  });

  final String title;
  final String url;
  final VoidCallback onTap;

  String get _displayHost {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return url;
    }
    return uri.host;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      label: AppCopy.of(context).sourceSemanticLabel(title),
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _displayHost,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMono.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: theme.colorScheme.onSurface,
                    size: AppSize.icon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
