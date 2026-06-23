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

extension Responsive on BuildContext {
  static const double _baseWidth = 390.0;
  static const double _baseHeight = 844.0;

  /// Lower / upper bounds for the width scale factor.
  static const double _minScale = 0.85;
  static const double _maxScale = 1.20;

  MediaQueryData get _mq => MediaQuery.of(this);

  Size get screenSize => _mq.size;
  double get screenW => screenSize.width;
  double get screenH => screenSize.height;

  /// `true` on tablets / large foldables — callers can widen grids or padding.
  bool get isTablet => screenW >= 600;

  /// Width-based scale factor, clamped so layouts stay proportional.
  double get widthScale => (screenW / _baseWidth).clamp(_minScale, _maxScale);

  /// Height-based scale factor (for vertical rhythm on very short/tall screens).
  double get heightScale => (screenH / _baseHeight).clamp(_minScale, _maxScale);

  /// The active (already app-clamped) OS text scale. Fixed-height boxes
  /// multiply by this so they expand together with the text they wrap.
  double get textScale => _mq.textScaler.scale(1.0);

  /// Scale a design-space dp by screen width. Use for gaps, padding and icon
  /// sizes that should breathe with the device.
  double r(double dp) => dp * widthScale;

  /// Scale a design-space dp by screen *height* — for vertical gaps.
  double rh(double dp) => dp * heightScale;

  /// Fraction of the screen width / height. `wp(0.5)` == half the screen wide.
  double wp(double fraction) => screenW * fraction;
  double hp(double fraction) => screenH * fraction;

  /// A fixed-height component grown to fit the active text scale, so it never
  /// clips its own labels when the user enlarges system fonts. Combines the
  /// width scale with the text scale.
  double fixedH(double dp) => dp * widthScale * textScale.clamp(1.0, 1.25);

  /// Convenience: a responsive [SizedBox] gap (square by default).
  SizedBox gap(double dp) => SizedBox(width: r(dp), height: r(dp));
  SizedBox gapW(double dp) => SizedBox(width: r(dp));
  SizedBox gapH(double dp) => SizedBox(height: rh(dp));

  /// Responsive symmetric / all-side insets.
  EdgeInsets padAll(double dp) => EdgeInsets.all(r(dp));
  EdgeInsets padSym({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: r(h), vertical: rh(v));
}
