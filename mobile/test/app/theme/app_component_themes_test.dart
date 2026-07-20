import 'package:curitalk/app/theme/app_component_themes.dart';
import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('button themes', () {
    test('uses accessible pill-shaped primary button states', () {
      final ButtonStyle style = AppComponentThemes.filledButton.style!;

      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        AppPalette.primary,
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        AppPalette.onPrimary,
      );
      expect(
        style.backgroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
        AppSemanticColors.light.disabledSurface,
      );
      expect(
        style.minimumSize!.resolve(<WidgetState>{}),
        const Size(0, AppSize.touchTarget),
      );
      expect(style.shape!.resolve(<WidgetState>{}), isA<StadiumBorder>());
    });

    test('strengthens the secondary border when focused', () {
      final ButtonStyle style = AppComponentThemes.outlinedButton.style!;
      final BorderSide normal = style.side!.resolve(<WidgetState>{})!;
      final BorderSide focused = style.side!.resolve(<WidgetState>{
        WidgetState.focused,
      })!;

      expect(normal.width, AppBorderWidth.hairline);
      expect(normal.color, AppPalette.primary);
      expect(focused.width, AppBorderWidth.focused);
      expect(focused.color, AppSemanticColors.light.focusBorder);
    });
  });

  group('form and selection themes', () {
    test('uses tokenized input borders and content padding', () {
      final InputDecorationTheme theme = AppComponentThemes.inputDecoration;
      final OutlineInputBorder enabled =
          theme.enabledBorder! as OutlineInputBorder;
      final OutlineInputBorder focused =
          theme.focusedBorder! as OutlineInputBorder;

      expect(theme.filled, isTrue);
      expect(theme.fillColor, AppPalette.canvas);
      expect(
        theme.contentPadding,
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      );
      expect(enabled.borderSide.width, AppBorderWidth.hairline);
      expect(focused.borderSide.width, AppBorderWidth.focused);
      expect(focused.borderSide.color, AppSemanticColors.light.focusBorder);
    });

    test('uses monochrome pill-shaped chips', () {
      final ChipThemeData theme = AppComponentThemes.chip;

      expect(theme.backgroundColor, AppPalette.canvas);
      expect(theme.selectedColor, AppSemanticColors.light.selectedSurface);
      expect(
        theme.secondaryLabelStyle?.color,
        AppSemanticColors.light.onSelected,
      );
      expect(theme.shape, isA<StadiumBorder>());
      expect(theme.showCheckmark, isFalse);
    });
  });

  group('container and navigation themes', () {
    test('keeps cards and bottom sheets flat and rounded', () {
      final CardThemeData card = AppComponentThemes.card;
      final BottomSheetThemeData sheet = AppComponentThemes.bottomSheet;

      expect(card.elevation, 0);
      expect(card.shape, isA<RoundedRectangleBorder>());
      expect(sheet.modalElevation, 0);
      expect(sheet.showDragHandle, isTrue);
      expect(sheet.shape, isA<RoundedRectangleBorder>());
    });

    test('uses selected and unselected bottom navigation states', () {
      final NavigationBarThemeData theme = AppComponentThemes.navigationBar;
      final IconThemeData selected = theme.iconTheme!.resolve(<WidgetState>{
        WidgetState.selected,
      })!;
      final IconThemeData unselected = theme.iconTheme!.resolve(
        <WidgetState>{},
      )!;

      expect(theme.height, AppSize.bottomNavigationHeight);
      expect(theme.indicatorColor, AppSemanticColors.light.selectedSurface);
      expect(selected.color, AppSemanticColors.light.onSelected);
      expect(unselected.color, AppPalette.inkSecondary);
    });

    test('registers every component theme in AppTheme', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.filledButtonTheme, AppComponentThemes.filledButton);
      expect(theme.outlinedButtonTheme, AppComponentThemes.outlinedButton);
      expect(
        theme.inputDecorationTheme.fillColor,
        AppComponentThemes.inputDecoration.fillColor,
      );
      expect(
        theme.inputDecorationTheme.focusedBorder,
        AppComponentThemes.inputDecoration.focusedBorder,
      );
      expect(theme.chipTheme, AppComponentThemes.chip);
      expect(theme.cardTheme, AppComponentThemes.card);
      expect(theme.bottomSheetTheme, AppComponentThemes.bottomSheet);
      expect(theme.navigationBarTheme, AppComponentThemes.navigationBar);
    });
  });
}
