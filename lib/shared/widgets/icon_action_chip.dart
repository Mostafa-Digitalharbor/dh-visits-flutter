import 'package:flutter/material.dart';

import '../../app/design/app_decor.dart';
import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';
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

  /// Long-press label, and what a screen reader announces. A glyph-only button
  /// needs one; the back chip uses the platform's own "Back".
  final String? tooltip;

  const IconActionChip({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // The panel is drawn with [Ink], not a decorated Container: the ripple
    // paints on the nearest Material, which an opaque Container would cover —
    // the tap had no visible feedback at all.
    //
    // Scaled by device width, not text scale: the chip holds a glyph, and a
    // glyph does not get taller when the user enlarges system fonts. It does
    // need to shrink on a 320dp bar that has to fit three of them beside a
    // two-line title — while the *touch* area keeps the 48dp minimum.
    final side = context.r(CompSz.chip);
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Ink(
          width: side,
          height: side,
          decoration: AppDecor.panel(context, radius: Radii.sm),
          child: Icon(
            icon,
            size: context.r(IconSz.chip),
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
    final target = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: IconSz.hit,
        minHeight: IconSz.hit,
      ),
      child: Center(child: button),
    );
    final label = tooltip;
    return label == null ? target : Tooltip(message: label, child: target);
  }
}
