import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class NaturalFeedbackBadge extends StatelessWidget {
  const NaturalFeedbackBadge({
    required this.onTap,
    this.label = 'Looks natural',
    super.key,
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onSurface;

    return ActionChip(
      avatar: Icon(
        Icons.check_circle_rounded,
        color: foreground,
        size: AppSize.icon,
      ),
      label: Text(label.toUpperCase()),
      onPressed: onTap,
      side: BorderSide(color: foreground, width: AppBorderWidth.hairline),
      shape: const StadiumBorder(),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}
