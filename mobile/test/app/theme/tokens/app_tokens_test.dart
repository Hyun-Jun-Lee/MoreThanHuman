import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foundation design tokens', () {
    test('exposes the documented core and block colors', () {
      expect(AppPalette.primary, const Color(0xFF000000));
      expect(AppPalette.canvas, const Color(0xFFFFFFFF));
      expect(AppPalette.blockLime, const Color(0xFFD9F99D));
      expect(AppPalette.blockLilac, const Color(0xFFE8E4F4));
      expect(AppPalette.blockCream, const Color(0xFFF6F4EB));
      expect(AppPalette.accentTerracotta, const Color(0xFF8D4926));
    });

    test('uses the documented spacing and shape scale', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.sectionGap, 48);
      expect(AppRadius.md, 12);
      expect(AppRadius.lg, 24);
      expect(AppRadius.pill, 50);
      expect(AppBorderWidth.hairline, 1);
      expect(AppBorderWidth.focused, 2);
    });

    test('uses bundled font families and mobile type values', () {
      expect(AppTypography.sansFontFamily, 'Inter');
      expect(AppTypography.monoFontFamily, 'JetBrains Mono');
      expect(AppTypography.displayXl.fontSize, 48);
      expect(AppTypography.displayXl.fontWeight, FontWeight.w800);
      expect(AppTypography.body.fontSize, 18);
      expect(AppTypography.labelMono.letterSpacing, 0.7);
    });

    test('keeps interactive sizes at accessible minimums', () {
      expect(AppSize.touchTarget, greaterThanOrEqualTo(48));
      expect(AppSize.inputMinHeight, greaterThanOrEqualTo(48));
      expect(AppSize.icon, 24);
      expect(AppSize.iconButton, 44);
      expect(AppSize.bottomNavigationHeight, 72);
    });
  });
}
