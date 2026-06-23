import 'package:flutter/material.dart';

class AppSelectionChip extends StatelessWidget {
  const AppSelectionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label.toUpperCase()),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
