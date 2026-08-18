import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../extensions/context_extensions.dart';

/// A short rounded progress bar used under a name in the leaderboards.
///
/// `LinearProgressIndicator` draws square ends, so both leaderboards wrapped it
/// in the same `ClipRRect`. They had also drifted on the track colour — one used
/// `surfaceContainerHighest`, the other `surfaceContainerHigh` — which is the
/// kind of difference nobody chooses on purpose.
class ProgressTrack extends StatelessWidget {
  /// 0–1. Clamped, so a caller can pass a raw ratio without guarding it.
  final double value;

  /// Colour of the filled portion.
  final Color color;

  final double height;

  const ProgressTrack({
    super.key,
    required this.value,
    required this.color,
    this.height = CompSz.trackHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.badge),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0, 1),
        backgroundColor: context.colors.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
