import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';

/// Animated number that counts from 0 to a value on first build.
///
/// Counts a whole number with an optional short unit after it — `27`, `92%`,
/// `92٪`, `12 كم` — and shows anything else (`00:58`, `3.5`) as it is. The unit
/// used to be limited to `%`, which is why a screen had to hard-code the Latin
/// sign next to an Arabic `٪` to get the animation. Under reduced motion the
/// final figure is shown straight away.
/// Matches the design package `lib/count_up_text.dart`.
class CountUpText extends StatelessWidget {
  final String value; // "27", "92%", "214", "00:58"
  final TextStyle? style;
  final Duration duration;
  const CountUpText(this.value,
      {super.key, this.style, this.duration = AppDurations.countUp});

  // Compiled once at class-load rather than three times per build. These are
  // on KPI and metric tiles, which rebuild on every bloc emit — and a `RegExp`
  // literal in `build()` is a fresh compile each time, not a cached constant.
  /// A whole number, then an optional unit that holds no digits.
  static final _countable = RegExp(r'^(\d+)(\s*[^\d\s:.,][^\d]*)?$');

  @override
  Widget build(BuildContext context) {
    final match = _countable.firstMatch(value.trim());
    final target = match == null ? null : int.tryParse(match.group(1)!);
    if (target == null || MediaQuery.disableAnimationsOf(context)) {
      return Text(value, style: style);
    }
    final tail = match!.group(2) ?? '';
    final end = target.toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: end),
      duration: duration,
      curve: Curves.easeOutCubic,
      // The settled frame shows [value] itself, exactly as the reduced-motion
      // path does: `v.round()` would drop leading zeros and surrounding space,
      // and past 2^53 a double cannot hold the figure, so it ended one off.
      builder: (_, v, __) =>
          Text(v == end ? value : '${v.round()}$tail', style: style),
    );
  }
}
