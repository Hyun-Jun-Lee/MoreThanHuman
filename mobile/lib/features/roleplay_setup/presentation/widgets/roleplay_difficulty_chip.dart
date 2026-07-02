import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_difficulty.dart';
import 'package:flutter/material.dart';

class RoleplayDifficultyChip extends StatelessWidget {
  const RoleplayDifficultyChip({
    required this.difficulty,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final RoleplayDifficulty difficulty;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppSelectionChip(
          label: difficulty.label,
          selected: selected,
          onSelected: (_) => onSelected(),
        ),
        if (selected) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: 220,
            child: Text(
              difficulty.description,
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
