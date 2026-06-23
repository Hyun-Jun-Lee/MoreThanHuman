import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.semanticLabel,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          errorText: errorText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
