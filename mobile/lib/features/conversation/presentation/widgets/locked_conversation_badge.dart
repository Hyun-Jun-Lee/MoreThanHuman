import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

class LockedConversationBadge extends StatelessWidget {
  const LockedConversationBadge({
    required this.dimension,
    required this.iconSize,
    super.key,
  });

  final double dimension;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppPalette.lockedSlotBadge,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.lock_rounded,
            size: iconSize,
            color: AppPalette.inkSecondary,
          ),
        ),
      ),
    );
  }
}
