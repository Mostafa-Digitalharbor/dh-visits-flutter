// app_dimens.dart — spacing, radii, icon sizes, durations. px == dp.
import 'package:flutter/animation.dart';

class Insets {
  static const x1 = 4.0,  x2 = 8.0,  x3 = 12.0, x4 = 16.0, x5 = 20.0,
               x6 = 24.0, x8 = 32.0, x10 = 40.0, x12 = 48.0, x16 = 64.0;
  static const screen = 16.0;   // screen edge padding
  static const cardGap = 16.0;  // between stacked cards
  static const cardPad = 16.0;  // card inner (14–20 in places)
}

class Radii {
  static const xs = 8.0, sm = 12.0, md = 16.0, lg = 20.0, xl = 28.0, pill = 999.0, btn = 14.0;
}

class IconSz {
  static const xs = 16.0, sm = 20.0, md = 24.0, lg = 28.0, xl = 40.0;
  static const hit = 48.0;
}

class Durations {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const navSlide = Duration(milliseconds: 340);
}

class Curves2 {
  static const standard   = Cubic(0.2, 0, 0, 1);    // ease-standard / emphasized
  static const decelerate = Cubic(0, 0, 0, 1);      // ease-decelerate
  static const stagger    = Cubic(0.2, 0.7, 0.3, 1);
}
