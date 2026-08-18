import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';

/// Animated number that counts from 0 to a value on first build. Keeps a
/// trailing unit (%, كم) and skips non-numeric strings (e.g. "00:58").
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
  static final _simple = RegExp(r'^\d+%?$');
  static final _digits = RegExp(r'[^\d.]');
  static final _nonDigits = RegExp(r'[\d.\s]');

  @override
  Widget build(BuildContext context) {
    if (!_simple.hasMatch(value)) return Text(value, style: style);
    final target = double.tryParse(value.replaceAll(_digits, '')) ?? 0;
    final tail = value.replaceAll(_nonDigits, '');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}$tail', style: style),
    );
  }
}
