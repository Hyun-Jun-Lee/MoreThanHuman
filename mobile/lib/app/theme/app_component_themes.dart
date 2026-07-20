import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppComponentThemes {
  static final FilledButtonThemeData filledButton = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppPalette.primary,
      foregroundColor: AppPalette.onPrimary,
      disabledBackgroundColor: AppSemanticColors.light.disabledSurface,
      disabledForegroundColor: AppSemanticColors.light.onDisabled,
      minimumSize: const Size(0, AppSize.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      textStyle: AppTypography.button,
      shape: const StadiumBorder(),
      elevation: 0,
    ),
  );

  static final OutlinedButtonThemeData outlinedButton = OutlinedButtonThemeData(
    style:
        OutlinedButton.styleFrom(
          backgroundColor: AppPalette.canvas,
          foregroundColor: AppPalette.ink,
          disabledBackgroundColor: AppSemanticColors.light.disabledSurface,
          disabledForegroundColor: AppSemanticColors.light.onDisabled,
          minimumSize: const Size(0, AppSize.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: AppTypography.button,
          shape: const StadiumBorder(),
        ).copyWith(
          side: WidgetStateProperty.resolveWith<BorderSide>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: AppSemanticColors.light.onDisabled,
                width: AppBorderWidth.hairline,
              );
            }
            if (states.contains(WidgetState.focused)) {
              return BorderSide(
                color: AppSemanticColors.light.focusBorder,
                width: AppBorderWidth.focused,
              );
            }
            return const BorderSide(
              color: AppPalette.primary,
              width: AppBorderWidth.hairline,
            );
          }),
        ),
  );

  static final TextButtonThemeData textButton = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppPalette.ink,
      disabledForegroundColor: AppSemanticColors.light.onDisabled,
      minimumSize: const Size(0, AppSize.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      textStyle: AppTypography.button,
      shape: const StadiumBorder(),
    ),
  );

  static final IconButtonThemeData iconButton = IconButtonThemeData(
    style: IconButton.styleFrom(
      backgroundColor: AppPalette.surfaceSoft,
      foregroundColor: AppPalette.ink,
      disabledBackgroundColor: AppSemanticColors.light.disabledSurface,
      disabledForegroundColor: AppSemanticColors.light.onDisabled,
      minimumSize: const Size.square(AppSize.touchTarget),
      iconSize: AppSize.icon,
      shape: const CircleBorder(),
    ),
  );

  static final InputDecorationTheme inputDecoration = InputDecorationTheme(
    filled: true,
    fillColor: AppPalette.canvas,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    constraints: const BoxConstraints(minHeight: AppSize.inputMinHeight),
    hintStyle: AppTypography.bodySm.copyWith(color: AppPalette.inkSecondary),
    labelStyle: AppTypography.bodySm.copyWith(color: AppPalette.inkSecondary),
    floatingLabelStyle: AppTypography.bodySm.copyWith(color: AppPalette.ink),
    errorStyle: AppTypography.bodySm.copyWith(color: AppPalette.semanticError),
    border: _inputBorder(AppPalette.hairline, AppBorderWidth.hairline),
    enabledBorder: _inputBorder(AppPalette.hairline, AppBorderWidth.hairline),
    focusedBorder: _inputBorder(
      AppSemanticColors.light.focusBorder,
      AppBorderWidth.focused,
    ),
    disabledBorder: _inputBorder(
      AppPalette.hairlineSoft,
      AppBorderWidth.hairline,
    ),
    errorBorder: _inputBorder(
      AppPalette.semanticError,
      AppBorderWidth.hairline,
    ),
    focusedErrorBorder: _inputBorder(
      AppPalette.semanticError,
      AppBorderWidth.focused,
    ),
  );

  static final ChipThemeData chip = ChipThemeData(
    backgroundColor: AppPalette.canvas,
    disabledColor: AppSemanticColors.light.disabledSurface,
    selectedColor: AppSemanticColors.light.selectedSurface,
    secondarySelectedColor: AppSemanticColors.light.selectedSurface,
    surfaceTintColor: AppPalette.canvas,
    showCheckmark: false,
    checkmarkColor: AppSemanticColors.light.onSelected,
    labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    side: const BorderSide(
      color: AppPalette.hairline,
      width: AppBorderWidth.hairline,
    ),
    shape: const StadiumBorder(),
    labelStyle: AppTypography.captionMono.copyWith(color: AppPalette.ink),
    secondaryLabelStyle: AppTypography.captionMono.copyWith(
      color: AppSemanticColors.light.onSelected,
    ),
    elevation: 0,
    pressElevation: 0,
  );

  static const CardThemeData card = CardThemeData(
    color: AppPalette.canvas,
    surfaceTintColor: AppPalette.canvas,
    shadowColor: AppPalette.overlayScrim,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
    ),
  );

  static const BottomSheetThemeData bottomSheet = BottomSheetThemeData(
    backgroundColor: AppPalette.canvas,
    modalBackgroundColor: AppPalette.canvas,
    surfaceTintColor: AppPalette.canvas,
    elevation: 0,
    modalElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    showDragHandle: true,
    dragHandleColor: AppPalette.hairline,
    dragHandleSize: Size(AppSpacing.xl, AppSpacing.xxs),
  );

  static final NavigationBarThemeData navigationBar = NavigationBarThemeData(
    height: AppSize.bottomNavigationHeight,
    backgroundColor: AppPalette.canvas,
    elevation: 0,
    shadowColor: AppPalette.overlayScrim,
    surfaceTintColor: AppPalette.canvas,
    indicatorColor: AppSemanticColors.light.selectedSurface,
    indicatorShape: const StadiumBorder(),
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return AppTypography.captionMono.copyWith(color: AppPalette.ink);
      }
      return AppTypography.captionMono.copyWith(color: AppPalette.inkSecondary);
    }),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(color: AppSemanticColors.light.onSelected);
      }
      return const IconThemeData(color: AppPalette.inkSecondary);
    }),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  );

  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
