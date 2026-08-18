// app_typography.dart — Cairo type scale, 1:1 with 01-foundations.md §2.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The only font sizes the app is allowed to use.
///
/// The composite styles in [AppType] cover most text, but plenty of call sites
/// legitimately need a different weight or colour than a token bakes in, and
/// were reaching for a bare `fontSize:` literal to get there. That left 55
/// inline sizes across 18 files — including 11.5, 12.5 and 13.5, rungs that
/// exist nowhere in the foundations doc and arrived purely by drift.
///
/// Sizes live here so the ladder stays finite and reviewable, while weight and
/// colour stay at the call site where they carry meaning.
class FontSz {
  FontSz._();

  /// 9 — graphical annotations that sit inside a fixed shape: the map
  /// attribution strip, the rank numeral inside an 18dp medal. Not for prose;
  /// these do not grow with the OS text scale because their container can't.
  static const micro = 9.0;

  /// 10 — nav badge counts, the smallest caption still meant to be read.
  static const tiny = 10.0;

  /// 11 — eyebrows, chip captions.
  static const xs = 11.0;

  /// 12 — badges, chips, tabs, metric captions. The app's most common size.
  static const sm = 12.0;

  /// 13 — secondary body, list subtitles.
  static const base = 13.0;

  /// 14 — body, buttons.
  static const md = 14.0;

  /// 15 — settings rows, primary list titles.
  static const lg = 15.0;

  /// 16 — card titles, leaderboard avatar initials.
  static const xl = 16.0;

  /// 18 — greeting avatar initial.
  static const avatar = 18.0;

  /// 19 — app-bar titles.
  static const appBar = 19.0;

  /// 20 — the customer-list initial.
  static const listInitial = 20.0;

  /// 22 — the greeting name, the biggest text in the dashboard header.
  static const greeting = 22.0;

  /// 23 — auth sheet heading ("Welcome back").
  static const authHeading = 23.0;

  /// 24 — settings profile initial.
  static const profileInitial = 24.0;

  /// 30 — the auth wordmark.
  static const wordmark = 30.0;

  /// 32 — customer-detail hero initial.
  static const heroInitial = 32.0;

  /// 26 — the value on an analytics metric tile. Two of these sit side by side,
  /// so it is a rung below the dashboard's full-width KPI.
  static const metric = 26.0;

  /// 34 — the dashboard KPI number, the largest figure in the app.
  static const kpi = 34.0;
}

class AppType {
  AppType._();

  static TextStyle _c(double size, FontWeight w, {double height = 1.45, double ls = 0}) =>
      GoogleFonts.cairo(fontSize: size, fontWeight: w, height: height, letterSpacing: ls);

  // display / headline
  static final displayLg = _c(34, FontWeight.w800, height: 1.18, ls: -0.4); // live timer / hero numbers
  static final displayMd = _c(28, FontWeight.w700, height: 1.18, ls: -0.4);
  static final headline = _c(24, FontWeight.w700, height: 1.30, ls: -0.2);
  // titles
  static final appBarTitle = _c(19, FontWeight.w800, height: 1.30, ls: -0.2);
  static final titleLg = _c(20, FontWeight.w700, height: 1.30, ls: -0.2);
  static final cardTitle = _c(16, FontWeight.w800, height: 1.30); // customer name on cards
  static final titleMd = _c(17, FontWeight.w600, height: 1.30);
  static final titleSm = _c(15, FontWeight.w600, height: 1.45);
  // body
  static final bodyLg = _c(16, FontWeight.w400, height: 1.45);
  static final bodyMd = _c(14, FontWeight.w400, height: 1.45);
  static final bodySm = _c(13, FontWeight.w400, height: 1.45);
  // labels
  static final button = _c(14, FontWeight.w700, height: 1.30, ls: 0.3);
  static final labelMd = _c(12, FontWeight.w600, height: 1.30, ls: 0.3); // badges, chips, tabs
  static final eyebrow = _c(11, FontWeight.w700, height: 1.30, ls: 0.3); // app-bar eyebrow (uppercase)

  // numbers — tabular figures + weight 800
  static TextStyle number(double size, Color color) => GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Builds the Material [TextTheme] from the Cairo scale.
TextTheme buildCairoTextTheme(Brightness b, Color onSurface) {
  final base = ThemeData(brightness: b).textTheme;
  return GoogleFonts.cairoTextTheme(base)
      .copyWith(
        displayLarge: AppType.displayLg,
        displayMedium: AppType.displayMd,
        headlineMedium: AppType.headline,
        titleLarge: AppType.titleLg,
        titleMedium: AppType.titleMd,
        titleSmall: AppType.titleSm,
        bodyLarge: AppType.bodyLg,
        bodyMedium: AppType.bodyMd,
        bodySmall: AppType.bodySm,
        labelLarge: AppType.button,
        labelMedium: AppType.labelMd,
        labelSmall: AppType.eyebrow,
      )
      .apply(bodyColor: onSurface, displayColor: onSurface);
}
