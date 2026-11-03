import 'package:flutter/material.dart';

class AppSelectionChip extends StatelessWidget {
  const AppSelectionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.uppercaseLabel = true,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool uppercaseLabel;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(uppercaseLabel ? label.toUpperCase() : label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
