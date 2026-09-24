import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../core/utils/app_number.dart';
import '../extensions/context_extensions.dart';

/// A short rounded progress bar — under a name in the leaderboards, and across
/// the greeting header.
///
/// `LinearProgressIndicator` draws square ends and takes one flat colour, so
/// the leaderboards wrapped it in a `ClipRRect` and the greeting header drew
/// its own gradient bar from a `Stack`. One widget covers both, and fills from
/// the reading start, so it mirrors in Arabic.
class ProgressTrack extends StatelessWidget {
  /// 0–1. Clamped, so a caller can pass a raw ratio without guarding it.
  final double value;

  /// Colour of the filled portion. Ignored when [gradient] is set.
  final Color? color;
  final Gradient? gradient;

  /// The unfilled portion. Defaults to the theme's highest container tone.
  final Color? trackColor;

  final double height;

  const ProgressTrack({
    super.key,
    required this.value,
    this.color,
    this.gradient,
    this.trackColor,
    this.height = CompSz.trackHeight,
  }) : assert(color != null || gradient != null);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.pill);
    // NaN first: `double.nan.clamp(0, 1)` is 1.0 in Dart, so a raw `0 / 0`
    // ratio (a board whose leader has a zero count) drew a *full* bar.
    final fraction = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      value: AppNumber.percent(context.s, (fraction * 100).round()),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: trackColor ?? context.colors.surfaceContainerHighest,
          borderRadius: radius,
        ),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: gradient == null ? color : null,
              gradient: gradient,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}
