// app_colors.dart — exact ColorScheme (light + dark) for Customer Visits.
// Hex values are 1:1 with 01-foundations.md. Extra semantic tokens live in AppX (app_theme.dart).
import 'package:flutter/material.dart';

class AppColors {
  // ---- raw brand ramps (use where a specific tone is needed) ----
  static const navy700 = Color(0xFF1E2A6E); // ★ primary
  static const navy600 = Color(0xFF2C3A86);
  static const navy300 = Color(0xFF8C95CE);
  static const navy100 = Color(0xFFDDE1F5);
  static const navy900 = Color(0xFF0B1240);
  static const cyan500 = Color(0xFF3FBFD9); // ★ accent
  static const cyan400 = Color(0xFF5FD0E6);
  static const cyan300 = Color(0xFF8FE0EF); // undo action colour
  static const ink     = Color(0xFF14131C); // toast bg / primary text

  // ---- semantic hues ----
  static const green   = Color(0xFF1E9E63);
  static const green400= Color(0xFF57D89B);
  static const amber   = Color(0xFFE8910C);
  static const amber400= Color(0xFFFFB955);
  static const red     = Color(0xFFC8364B);
  static const red400  = Color(0xFFFF8A93);

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: navy700, onPrimary: Color(0xFFFFFFFF),
    primaryContainer: navy100, onPrimaryContainer: navy900,
    secondary: navy600, onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: navy100, onSecondaryContainer: Color(0xFF141B52),
    tertiary: cyan500, onTertiary: Color(0xFF04323B),
    tertiaryContainer: Color(0xFFE0F7FB), onTertiaryContainer: Color(0xFF0C4351),
    error: red, onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBDCE0), onErrorContainer: Color(0xFF410008),
    surface: Color(0xFFF6F5FB), onSurface: ink,                 // app background
    onSurfaceVariant: Color(0xFF5E5A79),                        // text-secondary
    surfaceContainerLowest: Color(0xFFFFFFFF),                  // card surface
    surfaceContainerLow: Color(0xFFFBFAFE),
    surfaceContainer: Color(0xFFF2F1F8),
    surfaceContainerHigh: Color(0xFFECEAF4),
    surfaceContainerHighest: Color(0xFFE6E4F0),
    outline: Color(0xFFB5B2C9), outlineVariant: Color(0xFFDEDCEC),
    surfaceTint: navy700, shadow: Color(0xFF000000), scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2A2839), onInverseSurface: Color(0xFFF6F5FB), inversePrimary: Color(0xFFBAC0E6),
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: navy300, onPrimary: navy900,
    primaryContainer: Color(0xFF28306B), onPrimaryContainer: navy100,
    secondary: navy300, onSecondary: navy900,
    secondaryContainer: Color(0xFF28306B), onSecondaryContainer: navy100,
    tertiary: cyan400, onTertiary: Color(0xFF04323B),
    tertiaryContainer: Color(0xFF134454), onTertiaryContainer: Color(0xFFBFF0F7),
    error: red400, onError: Color(0xFF410008),
    errorContainer: Color(0xFF5C141C), onErrorContainer: Color(0xFFFFDADD),
    surface: Color(0xFF0A0B0F), onSurface: Color(0xFFECECF4),
    onSurfaceVariant: Color(0xFFB7B6C8),
    surfaceContainerLowest: Color(0xFF0E0F15),                 // card surface
    surfaceContainerLow: Color(0xFF131420),
    surfaceContainer: Color(0xFF181A26),
    surfaceContainerHigh: Color(0xFF1F2230),
    surfaceContainerHighest: Color(0xFF272A3A),
    outline: Color(0xFF4A4C5C), outlineVariant: Color(0xFF2E3140),
    surfaceTint: navy300, shadow: Color(0xFF000000), scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECECF4), onInverseSurface: Color(0xFF2A2839), inversePrimary: navy700,
  );
}
