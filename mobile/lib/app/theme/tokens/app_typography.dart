import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String sansFontFamily = 'Inter';
  static const String monoFontFamily = 'JetBrains Mono';

  static const TextStyle displayXl = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -1.44,
  );

  static const TextStyle displayLg = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.8,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.32,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.26,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.14,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.14,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle button = TextStyle(
    fontFamily: sansFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle labelMono = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.7,
  );

  static const TextStyle captionMono = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 1.2,
  );
}
