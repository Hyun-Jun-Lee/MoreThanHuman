import 'package:curitalk/app/app.dart';
import 'package:curitalk/app/theme/app_color_scheme.dart';
import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColorScheme', () {
    test('maps the monochrome foundation to Material roles', () {
      const ColorScheme colors = AppColorScheme.light;

      expect(colors.brightness, Brightness.light);
      expect(colors.primary, AppPalette.primary);
      expect(colors.onPrimary, AppPalette.onPrimary);
      expect(colors.surface, AppPalette.canvas);
      expect(colors.onSurface, AppPalette.ink);
      expect(colors.error, AppPalette.semanticError);
      expect(colors.inverseSurface, AppPalette.blockNavy);
    });
  });

  group('AppSemanticColors', () {
    test('maps conversation, feedback, and state roles', () {
      final AppSemanticColors colors = AppSemanticColors.light;

      expect(colors.userMessageSurface, AppPalette.inverseCanvas);
      expect(colors.onUserMessage, AppPalette.inverseInk);
      expect(colors.grammarOriginalSurface, AppPalette.blockLilac);
      expect(colors.grammarSuggestionSurface, AppPalette.blockBlue);
      expect(colors.topicReadySurface, AppPalette.blockLime);
      expect(colors.onSearchRetry, AppPalette.semanticWarning);
      expect(colors.selectedSurface, AppPalette.primary);
      expect(
        colors.onDisabled.a,
        closeTo(AppSemanticColors.disabledContentOpacity, 0.001),
      );
      expect(colors.scrim.a, closeTo(AppSemanticColors.scrimOpacity, 0.001));
    });

    test('supports copy and interpolation', () {
      final AppSemanticColors colors = AppSemanticColors.light;
      final AppSemanticColors changed = colors.copyWith(
        focusBorder: AppPalette.blockBlue,
      );

      expect(changed.focusBorder, AppPalette.blockBlue);
      expect(changed.userMessageSurface, colors.userMessageSurface);

      final AppSemanticColors midpoint = colors.lerp(changed, 0.5);
      expect(
        midpoint.focusBorder,
        Color.lerp(colors.focusBorder, changed.focusBorder, 0.5),
      );
    });
  });

  group('AppTheme', () {
    test('registers the light color and semantic themes', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.colorScheme, AppColorScheme.light);
      expect(
        theme.extension<AppSemanticColors>(),
        same(AppSemanticColors.light),
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Pretendard');
    });

    testWidgets('is applied at the Curitalk app root', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: CuritalkApp()));

      final BuildContext context = tester.element(find.text('CURITALK'));
      final ThemeData theme = Theme.of(context);

      expect(theme.colorScheme.primary, AppPalette.primary);
      expect(theme.extension<AppSemanticColors>(), isNotNull);
    });
  });
}
