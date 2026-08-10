import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';

/// A tinted rounded square with a centred icon — the leading element of almost
/// every row in the app (detail rows, participants, attachments, metric tiles).
///
/// Before this existed the same eight lines were re-typed at each site, and they
/// had already drifted: some used `Radii.tile`, some `Radii.sm`, alphas ranged
/// 0.12–0.14 and icon sizes 18–24 with no reason behind the difference. The
/// defaults here are the shape the majority used; the constructor still exposes
/// every dimension so the two sites that legitimately differ (the analytics
/// tile's larger badge, the hero header's white-on-gradient one) stay pixel
/// identical instead of being forced into an average.
class IconBadge extends StatelessWidget {
  /// The glyph drawn in the centre.
  final IconData icon;

  /// Drives both the icon colour and — at [tintAlpha] — the background.
  final Color color;

  /// Side length of the square. Null means the badge sizes to [padding]
  /// instead, which is what the tappable map button needs.
  final double? size;

  final double iconSize;
  final double radius;
  final double tintAlpha;

  /// Set when the icon should not use [color] — the hero header draws a cyan
  /// glyph on a white-tinted square.
  final Color? iconColor;

  /// Used in place of [size] when the badge must hug its icon.
  final EdgeInsetsGeometry? padding;

  /// Material Symbols' optical fill axis. Filled glyphs read as "active".
  final double? fill;

  /// Replaces the tinted background outright. The customer stats tiles use the
  /// theme's solid `primaryContainer` / `successContainer` rather than a tint,
  /// so they stay legible against the card they sit on.
  final Color? background;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize = 19,
    this.radius = Radii.tile,
    this.tintAlpha = 0.12,
    this.iconColor,
    this.padding,
    this.fill,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: padding == null ? size : null,
      height: padding == null ? size : null,
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, fill: fill, color: iconColor ?? color),
    );
  }
}
