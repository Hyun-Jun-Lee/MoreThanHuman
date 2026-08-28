import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

enum AppAsyncStateType { loading, error, empty }

class AppAsyncStateView extends StatelessWidget {
  const AppAsyncStateView.loading({this.message, super.key})
    : type = AppAsyncStateType.loading,
      title = null,
      onRetry = null,
      icon = null;

  const AppAsyncStateView.error({
    this.title,
    this.message,
    this.onRetry,
    this.icon,
    super.key,
  }) : type = AppAsyncStateType.error;

  const AppAsyncStateView.empty({
    this.title,
    this.message,
    this.icon,
    super.key,
  }) : type = AppAsyncStateType.empty,
       onRetry = null;

  final AppAsyncStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final String? resolvedTitle = title ?? switch (type) {
      AppAsyncStateType.error => copy.defaultErrorTitle,
      AppAsyncStateType.empty => copy.defaultEmptyTitle,
      AppAsyncStateType.loading => null,
    };
    final String? resolvedMessage = message ??
        (type == AppAsyncStateType.loading ? copy.defaultLoadingLabel : null);
    return Semantics(
      liveRegion: type != AppAsyncStateType.empty,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildVisual(context),
              if (resolvedTitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  resolvedTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMd.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
              if (resolvedMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  resolvedMessage,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(copy.retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisual(BuildContext context) {
    if (icon != null) {
      return icon!;
    }
    if (type == AppAsyncStateType.loading) {
      return const SizedBox.square(
        dimension: AppSize.iconButton,
        child: CircularProgressIndicator(strokeWidth: AppBorderWidth.focused),
      );
    }

    return Icon(
      type == AppAsyncStateType.error
          ? Icons.error_outline_rounded
          : Icons.inbox_outlined,
      color: type == AppAsyncStateType.error
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.onSurfaceVariant,
      size: AppSize.iconButton,
    );
  }
}
