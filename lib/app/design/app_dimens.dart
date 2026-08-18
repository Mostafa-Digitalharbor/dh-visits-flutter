// app_dimens.dart — spacing, radii, icon sizes, durations. px == dp.
// 1:1 with docs/design/flutter_build/01-foundations.md §3-5.
import 'package:flutter/animation.dart';

class Insets {
  Insets._();
  static const x1 = 4.0,
      x2 = 8.0,
      x3 = 12.0,
      x4 = 16.0,
      x5 = 20.0,
      x6 = 24.0,
      x8 = 32.0,
      x10 = 40.0,
      x12 = 48.0,
      x16 = 64.0;

  /// 2 — a hairline nudge: the gap between a title and the caption directly
  /// under it, where anything larger reads as two separate blocks.
  static const hair = 2.0;

  // ---- Half-steps ----
  // The 4dp grid above is the design system; these four sit between its rungs
  // and were each already in use as a bare literal dozens of times (a 6dp row
  // gutter, a 10dp icon-to-label gap, 14dp card padding, an 18dp section
  // break). Naming them keeps `context.r(...)` readable at the call site and
  // stops the next 13 or 15 from creeping in.
  static const x1h = 6.0;
  static const x2h = 10.0;
  static const x3h = 14.0;
  static const x4h = 18.0;

  static const screen = 16.0; // screen edge padding
  static const cardGap = 16.0; // between stacked cards
  static const cardPad = 16.0; // card inner (14–20 in places)
}

class Radii {
  Radii._();
  static const xs = 8.0, sm = 12.0, md = 16.0, lg = 20.0, xl = 28.0, pill = 999.0, btn = 14.0;

  /// 6dp — small inline badges and thin progress bars.
  static const badge = 6.0;

  /// 10dp — attachment tiles and inline detail rows.
  static const tile = 10.0;
}

class IconSz {
  IconSz._();
  static const xs = 16.0, sm = 20.0, md = 24.0, lg = 28.0, xl = 40.0;
  static const hit = 48.0;

  // ---- Rungs between the t-shirt sizes ----
  // These are not padding: an icon's size is set against the text it sits
  // beside, so the ladder is finer than [Insets]. Each rung below was already
  // in use as a bare literal at one or more call sites; naming them stops the
  // ladder growing a 13.5 the next time someone eyeballs a row.

  /// 13 — glyphs inside a dense meta line (a card's footer row), where the
  /// icon must not out-weigh the 12dp caption next to it.
  static const meta = 13.0;

  /// 14 — inline row glyphs: the check inside the "remember me" box, the
  /// leading marks on a timeline row.
  static const inline = 14.0;

  /// 15 — the glyph in an [InfoRow]'s circle and a [TonePill]'s leading icon.
  static const pill = 15.0;

  /// 17 — the customer type badge (company / individual).
  static const badge = 17.0;

  /// 18 — section headers, list leading icons, button icons. The app's most
  /// common icon size.
  static const label = 18.0;

  /// 21 — [IconActionChip]'s glyph, sized to centre in its 40dp square.
  static const chip = 21.0;

  /// 22 — the KPI tile's corner glyph and its chevron.
  static const tile = 22.0;

  /// 32 — a dialog's heading glyph.
  static const dialog = 32.0;

  /// 36 — the building glyph in the customer-detail hero circle.
  static const hero = 36.0;
}

/// Fixed component box sizes.
///
/// [Insets] covers the space *between* things; these are the things themselves
/// — the square of an action chip, the diameter of an avatar, the height of a
/// chart. They were previously bare literals at each call site, which is how
/// the same avatar ended up 42dp in one leaderboard and 44dp in another.
///
/// Every value here is a *design-space* dp. Widgets that must survive a large
/// OS font scale pass it through `context.r()` / `context.fixedH()` rather than
/// using it raw — see `responsive.dart`.
class CompSz {
  CompSz._();

  /// 18 — the rank medal that overlaps a leaderboard avatar.
  static const medal = 18.0;

  /// 20 — the "remember me" checkbox.
  static const checkbox = 20.0;

  /// 30 — the tinted circle behind an [InfoRow]'s glyph.
  static const infoDot = 30.0;

  /// 36 — the default [IconBadge] square.
  static const badge = 36.0;

  /// 38 — the analytics metric tile's larger badge.
  static const badgeLg = 38.0;

  /// 40 — [IconActionChip], and the shell app bar's logo tile.
  static const chip = 40.0;

  /// 42 — the leaderboard avatar.
  static const avatarSm = 42.0;

  /// 44 — the default [InitialAvatar], and the skeleton circle that stands in
  /// for it.
  static const avatar = 44.0;

  /// 72 — the customer-detail hero circle.
  static const avatarHero = 72.0;

  /// 148 — the weekly bar chart's plot box.
  static const chartHeight = 148.0;

  /// 16 — the width of a single bar in that chart.
  static const chartBar = 16.0;

  /// 200 — the customer-detail [SliverAppBar]'s expanded height.
  static const heroExpanded = 200.0;

  /// 6 — a [ProgressTrack]'s bar.
  static const trackHeight = 6.0;

  /// 1.5 — the outline weight on inputs, chips and the checkbox. Material's
  /// default hairline reads too faint against this app's surfaces.
  static const outlineWidth = 1.5;
}

/// Opacity tokens.
///
/// Named by *role*, not by value, because the same 0.12 means "tint a surface"
/// in one place and nothing in particular in another. Before this the codebase
/// carried 23 distinct alphas, including 0.10/0.12/0.14 used interchangeably
/// for the same tinted-panel effect and 0.8/0.82/0.85/0.88 for the same scrim.
class Alphas {
  Alphas._();

  /// 0.12 — a colour tinting a surface it must stay readable on: [IconBadge]
  /// backgrounds, KPI tiles, notification avatars.
  static const tint = 0.12;

  /// 0.15 — the same effect where the tile carries no border to reinforce it.
  static const tintStrong = 0.15;

  /// 0.18 — a white wash over a brand gradient (the hero avatar circle).
  static const wash = 0.18;

  /// 0.22 — the outer stop of a decorative halo.
  static const halo = 0.22;

  /// 0.30 — the hairline border drawn in a tile's own tint colour.
  static const border = 0.30;

  /// 0.50 — a foreground dimmed because its control is disabled.
  static const disabled = 0.50;

  /// 0.70 — a secondary glyph that should recede without disappearing.
  static const subdued = 0.70;

  /// 0.85 — a scrim over a map or photo so text stays legible on top.
  static const scrim = 0.85;
}

// Named `AppDurations` to avoid colliding with Flutter's Material `Durations`.
class AppDurations {
  AppDurations._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const navSlide = Duration(milliseconds: 340);

  /// How long a search field waits after the last keystroke before querying.
  static const searchDebounce = Duration(milliseconds: 350);

  /// Cross-fade between a list's loading / empty / error / content states.
  static const listSwitch = Duration(milliseconds: 280);

  /// How long a snackbar stays on screen.
  static const snack = Duration(seconds: 3);

  /// Release of a pressed [AppCard] — slower than the press so the card
  /// settles rather than snapping back.
  static const cardRelease = Duration(milliseconds: 180);

  /// A value animating up to its final figure: KPI count-ups and the weekly
  /// chart's bars. Long enough to read as counting, short enough that the
  /// screen is settled before the user has finished scanning it.
  static const countUp = Duration(milliseconds: 850);

  /// The weekly chart's bar growth. Slightly shorter than [countUp] so the
  /// bars have arrived by the time the numbers above them stop moving.
  static const barGrow = Duration(milliseconds: 700);

  /// One sweep of a skeleton's shimmer.
  static const shimmer = Duration(milliseconds: 1400);

  /// A picker sheet's search debounce. Shorter than [searchDebounce] because
  /// the sheet's list is the only thing on screen — the user is watching it.
  static const pickerDebounce = Duration(milliseconds: 300);
}

class AppCurves {
  AppCurves._();
  static const standard = Cubic(0.2, 0, 0, 1); // ease-standard / emphasized
  static const decelerate = Cubic(0, 0, 0, 1); // ease-decelerate
  static const stagger = Cubic(0.2, 0.7, 0.3, 1);
}
