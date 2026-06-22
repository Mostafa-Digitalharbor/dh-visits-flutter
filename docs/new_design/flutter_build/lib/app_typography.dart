// app_typography.dart — Cairo TextTheme matching 01-foundations.md §2.
// Use AppType.x in widgets, or rely on the Theme's textTheme below.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppType {
  static TextStyle _c(double size, FontWeight w, {double height = 1.45, double ls = 0}) =>
      GoogleFonts.cairo(fontSize: size, fontWeight: w, height: height, letterSpacing: ls);

  // display / headline
  static final displayLg = _c(34, FontWeight.w800, height: 1.18, ls: -0.4); // live timer / hero numbers
  static final displayMd = _c(28, FontWeight.w700, height: 1.18, ls: -0.4);
  static final headline  = _c(24, FontWeight.w700, height: 1.30, ls: -0.2);
  // titles
  static final appBarTitle = _c(19, FontWeight.w800, height: 1.30, ls: -0.2);
  static final titleLg = _c(20, FontWeight.w700, height: 1.30, ls: -0.2);
  static final cardTitle = _c(16, FontWeight.w800, height: 1.30);   // customer name on cards
  static final titleMd = _c(17, FontWeight.w600, height: 1.30);
  static final titleSm = _c(15, FontWeight.w600, height: 1.45);
  // body
  static final bodyLg = _c(16, FontWeight.w400, height: 1.45);
  static final bodyMd = _c(14, FontWeight.w400, height: 1.45);
  static final bodySm = _c(13, FontWeight.w400, height: 1.45);
  // labels
  static final button   = _c(14, FontWeight.w700, height: 1.30, ls: 0.3);
  static final labelMd  = _c(12, FontWeight.w600, height: 1.30, ls: 0.3); // badges, chips, tabs
  static final eyebrow  = _c(11, FontWeight.w700, height: 1.30, ls: 0.3); // app-bar eyebrow (uppercase)
  // numbers — apply tabular figures + weight 800 in-situ
  static TextStyle number(double size, Color color) => GoogleFonts.cairo(
    fontSize: size, fontWeight: FontWeight.w800, color: color,
    fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Build a TextTheme from the scale (wire into ThemeData if you prefer theme-driven text).
TextTheme buildCairoTextTheme(Brightness b) {
  final base = ThemeData(brightness: b).textTheme;
  return GoogleFonts.cairoTextTheme(base).copyWith(
    displayLarge: AppType.displayLg, headlineMedium: AppType.headline,
    titleLarge: AppType.titleLg, titleMedium: AppType.titleMd, titleSmall: AppType.titleSm,
    bodyLarge: AppType.bodyLg, bodyMedium: AppType.bodyMd, bodySmall: AppType.bodySm,
    labelLarge: AppType.button, labelMedium: AppType.labelMd, labelSmall: AppType.eyebrow,
  );
}
