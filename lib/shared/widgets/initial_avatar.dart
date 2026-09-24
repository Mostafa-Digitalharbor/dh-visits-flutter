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

  /// A letter or digit, so a name that opens with punctuation does not put a
  /// bracket in the circle.
  ///
  /// Anchored, and matched against one grapheme cluster at a time: it is the
  /// character the cluster *starts* with that decides. An unanchored test
  /// would accept a cluster because of a combining mark buried inside it.
  static final _startsWithLetterOrDigit =
      RegExp(r'^[\p{L}\p{N}]', unicode: true);

  /// Punctuation, separators and control characters — never an initial, even
  /// when the name holds nothing else. Symbols (`\p{S}`) are deliberately not
  /// here: an emoji is a perfectly good stand-in for a name that is only an
  /// emoji.
  ///
  /// Anchored for a sharper reason than the above: an emoji ZWJ sequence such
  /// as 👩‍💼 *contains* U+200D, a format character in `\p{C}`, so an
  /// unanchored test rejected the whole cluster and the emoji-only name fell
  /// through to `?`.
  static final _startsWithNonInitial =
      RegExp(r'^[\p{P}\p{Z}\p{C}]', unicode: true);

  /// The uppercase first *letter or digit* of [name], or `?` when there isn't
  /// one.
  ///
  /// Not simply the first character. Odoo names arrive with tag prefixes and
  /// decoration — the live server's own QA account is literally
  /// `[QA-AUTO] Workday Tester` — and taking character zero put a `[` in the
  /// avatar. On an Arabic screen the bidi algorithm then *mirrored* it, so the
  /// circle read `]`: a punctuation mark, pointing the wrong way, as
  /// somebody's initial.
  ///
  /// Trims first: Odoo happily returns names that are only whitespace.
  static String initialOf(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    for (final ch in trimmed.characters) {
      if (_startsWithLetterOrDigit.hasMatch(ch)) return ch.toUpperCase();
    }
    // No letter or digit anywhere: an emoji or another symbol still beats a
    // question mark, but a string of punctuation does not.
    for (final ch in trimmed.characters) {
      if (!_startsWithNonInitial.hasMatch(ch)) return ch.toUpperCase();
    }
    return '?';
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
