import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_scenario.dart';
import 'package:flutter/material.dart';

class RoleplayScenarioCard extends StatelessWidget {
  const RoleplayScenarioCard({
    required this.scenario,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final RoleplayScenario scenario;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSelectionCard(
      title: scenario.title,
      description: scenario.description,
      selected: selected,
      onTap: onTap,
      icon: Icon(scenario.icon),
      surfaceColor: selected ? AppPalette.blockCream : null,
      semanticLabel: AppCopy.of(
        context,
      ).roleplayScenarioSemanticLabel(scenario.title),
    );
  }
}
