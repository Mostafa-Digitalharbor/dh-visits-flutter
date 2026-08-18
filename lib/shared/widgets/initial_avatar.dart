import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Circular avatar showing a name's first letter — the app's stand-in wherever
/// there's no photo.
///
/// Ten screens were each computing `name[0].toUpperCase()` behind their own
/// null guard (in four different spellings) and painting their own circle. The
/// guard is the part worth centralising: an empty or whitespace-only name from
/// Odoo made `name[0]` throw a RangeError, and only some of the copies checked
/// for it.
class InitialAvatar extends StatelessWidget {
  final String? name;
  final double size;

  /// Defaults to the theme's avatar gradient. Ignored when [background] is set.
  final Gradient? gradient;

  /// Flat fill, for the places that want a solid tint rather than a gradient.
  final Color? background;

  final Color foreground;

  /// Shown instead of the initial — company/building glyphs on customer rows.
  final IconData? icon;

  /// White ring used by map pins so they stay legible over tiles.
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadow;

  const InitialAvatar({
    super.key,
    required this.name,
    this.size = CompSz.avatar,
    this.gradient,
    this.background,
    this.foreground = Colors.white,
    this.icon,
    this.borderColor,
    this.borderWidth = 0,
    this.shadow,
  });

  /// The uppercase first letter of [name], or `?` when there isn't one.
  /// Trims first: Odoo happily returns names that are only whitespace.
  static String initialOf(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        gradient: background == null
            ? (gradient ?? context.x.avatarGradient)
            : null,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: borderWidth,
              )
            : null,
        boxShadow: shadow,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: foreground)
          : Text(
              initialOf(name),
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                // Proportional so one widget serves 28dp chips and 72dp heroes.
                fontSize: size * 0.38,
              ),
            ),
    );
  }
}
