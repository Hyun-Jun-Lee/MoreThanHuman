import 'package:curitalk/app/theme/app_color_scheme.dart';
import 'package:curitalk/app/theme/app_component_themes.dart';
import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: AppColorScheme.light,
    scaffoldBackgroundColor: AppColorScheme.light.surface,
    fontFamily: AppTypography.sansFontFamily,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    filledButtonTheme: AppComponentThemes.filledButton,
    outlinedButtonTheme: AppComponentThemes.outlinedButton,
    textButtonTheme: AppComponentThemes.textButton,
    iconButtonTheme: AppComponentThemes.iconButton,
    inputDecorationTheme: AppComponentThemes.inputDecoration,
    chipTheme: AppComponentThemes.chip,
    cardTheme: AppComponentThemes.card,
    bottomSheetTheme: AppComponentThemes.bottomSheet,
    navigationBarTheme: AppComponentThemes.navigationBar,
    extensions: <ThemeExtension<dynamic>>[AppSemanticColors.light],
  );
}
