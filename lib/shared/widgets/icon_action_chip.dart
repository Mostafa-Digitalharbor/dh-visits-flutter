import 'package:flutter/material.dart';

import '../../app/design/app_decor.dart';
import '../../app/design/app_dimens.dart';
import '../extensions/context_extensions.dart';

/// A 40dp square action button on a raised panel — the back arrow on a
/// sub-screen's app bar, and the settings / notifications / customers buttons
/// on the shell's.
///
/// The two app bars each had their own private copy, and they had already
/// drifted: one drew the panel by hand instead of using [AppDecor.panel], and
/// its icon was a pixel smaller. They also disagreed on whether the button
/// gets a tooltip, which is an accessibility difference rather than a visual
/// one — so [tooltip] is optional here and applied when given.
class IconActionChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Long-press label, and what a screen reader announces. Omitted only where
  /// the icon is unambiguous on its own (the back arrow).
  final String? tooltip;

  const IconActionChip({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: AppDecor.panel(context, radius: Radii.sm),
        child: Icon(icon, size: 21, color: context.colors.onSurfaceVariant),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
