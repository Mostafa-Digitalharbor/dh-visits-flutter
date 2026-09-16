// responsive.dart — MediaQuery-driven sizing helpers.
//
// The fixed scales in [Insets]/[Radii]/[IconSz] stay the single source of
// truth for the *design* spacing. This layer adapts those values to the
// running device so gaps, paddings and fixed-height components breathe on
// small phones and large tablets — and, crucially, grow in step with the OS
// text-scale so nothing overflows on large accessibility font settings.
//
// Reference canvas is 390 × 844 dp (the design baseline in docs/design). On a
// 390-wide screen `r()` is the identity; narrower screens shrink, wider ones
// grow — both clamped to a sane band so layouts never collapse or balloon.
import 'package:flutter/widgets.dart';

import 'app_dimens.dart';

extension Responsive on BuildContext {
  static const double _baseWidth = 390.0;
  static const double _baseHeight = 844.0;

  /// Lower / upper bounds for the width scale factor.
  static const double _minScale = 0.85;
  static const double _maxScale = 1.20;

  /// The largest text scale fixed-height boxes grow for. Matches the clamp
  /// `App` applies to the whole tree.
  static const double maxTextScale = 1.25;
  static const double minTextScale = 0.9;

  /// The font size [textScale] is sampled at. Android 14 scales text
  /// non-linearly, so the factor at body size is what boxes should follow.
  static const double _textScaleSample = 14.0;

  // `sizeOf` / `textScalerOf` rather than `MediaQuery.of`: a widget that only
  // reads the size must not rebuild on every frame of the keyboard animation.
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenW => screenSize.width;
  double get screenH => screenSize.height;

  /// `true` on tablets / large foldables — callers can widen grids or padding.
  bool get isTablet => screenW >= CompSz.tabletBreakpoint;

  /// Wider than tall — a phone on its side, or most tablets.
  bool get isLandscape => screenW > screenH;

  /// Height the software keyboard currently covers (0 when hidden).
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;

  /// Width-based scale factor, clamped so layouts stay proportional.
  double get widthScale => (screenW / _baseWidth).clamp(_minScale, _maxScale);

  /// Height-based scale factor (for vertical rhythm on very short/tall screens).
  double get heightScale => (screenH / _baseHeight).clamp(_minScale, _maxScale);

  /// The active (already app-clamped) OS text scale. Fixed-height boxes
  /// multiply by this so they expand together with the text they wrap.
  double get textScale =>
      MediaQuery.textScalerOf(this).scale(_textScaleSample) / _textScaleSample;

  /// Scale a design-space dp by screen width. Use for gaps, padding and icon
  /// sizes that should breathe with the device.
  double r(double dp) => dp * widthScale;

  /// Scale a design-space dp by screen *height* — for vertical gaps.
  double rh(double dp) => dp * heightScale;

  /// Fraction of the screen width / height. `wp(0.5)` == half the screen wide.
  double wp(double fraction) => screenW * fraction;
  double hp(double fraction) => screenH * fraction;

  /// A fixed-height component grown to fit the active text scale, so it never
  /// clips its own labels when the user enlarges system fonts.
  ///
  /// Deliberately does **not** apply [widthScale]: text does not get narrower
  /// on a narrow phone, so multiplying by a sub-1.0 width factor shrank the
  /// box while its contents kept full height — clipping on exactly the 320dp
  /// screens this helper exists to protect. Growth is one-way; the box may get
  /// taller for large fonts but never shorter than its design height.
  double fixedH(double dp) => dp * textScale.clamp(1.0, maxTextScale);

  /// Convenience: a responsive [SizedBox] gap (square by default).
  SizedBox gap(double dp) => SizedBox(width: r(dp), height: r(dp));
  SizedBox gapW(double dp) => SizedBox(width: r(dp));
  SizedBox gapH(double dp) => SizedBox(height: rh(dp));

  /// Responsive symmetric / all-side insets.
  EdgeInsets padAll(double dp) => EdgeInsets.all(r(dp));
  EdgeInsets padSym({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: r(h), vertical: rh(v));
}
