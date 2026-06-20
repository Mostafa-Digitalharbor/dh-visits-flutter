// count_up_text.dart — animated number that counts from 0 to a value on first build.
// Keeps a trailing unit (%, كم) and skips non-numeric strings (e.g. "00:58").
import 'package:flutter/material.dart';

class CountUpText extends StatelessWidget {
  final String value;            // "27", "92%", "214", "00:58"
  final TextStyle? style;
  final Duration duration;
  const CountUpText(this.value, {super.key, this.style, this.duration = const Duration(milliseconds: 850)});

  @override
  Widget build(BuildContext context) {
    final isSimple = RegExp(r'^\d+%?$').hasMatch(value);
    if (!isSimple) return Text(value, style: style);
    final target = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final tail = value.replaceAll(RegExp(r'[\d.\s]'), ''); // "%" etc.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}$tail', style: style),
    );
  }
}
