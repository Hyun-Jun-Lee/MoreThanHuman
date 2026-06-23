import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = true,
    this.leading,
    this.trailing,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;
    final Widget labelText = Text(label, overflow: TextOverflow.ellipsis);

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel ?? label,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: FilledButton(
          onPressed: isEnabled ? onPressed : null,
          child: isLoading
              ? SizedBox.square(
                  dimension: AppSize.icon,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.onPrimary,
                    strokeWidth: AppBorderWidth.focused,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      leading!,
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (expand) Flexible(child: labelText) else labelText,
                    if (trailing != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
