import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

/// What an [InlineNotice] is telling the user.
enum NoticeTone {
  /// Background help — "ask your administrator if you don't know this".
  info,

  /// Something is degraded and the user should know why.
  warning,

  /// The last action failed; the text says what to do next.
  error,
}

/// A glyph and a paragraph on a tinted panel, sitting inside a form or a list.
///
/// The server screen's help hint and the profile's "permissions not loaded"
/// card were the same tree written twice. Unlike a snackbar this stays on
/// screen, which is what a message with a next step needs: the user reads it
/// while doing what it says.
class InlineNotice extends StatelessWidget {
  final String text;
  final NoticeTone tone;

  /// Defaults to a glyph matching [tone].
  final IconData? icon;

  const InlineNotice({
    super.key,
    required this.text,
    this.tone = NoticeTone.info,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final (background, foreground, glyph) = switch (tone) {
      NoticeTone.info => (cs.surfaceContainer, cs.onSurfaceVariant, Symbols.info),
      NoticeTone.warning => (
          x.warning.withValues(alpha: Alphas.tint),
          x.warning,
          Symbols.warning,
        ),
      NoticeTone.error => (cs.errorContainer, cs.onErrorContainer, Symbols.error),
    };
    return Semantics(
      liveRegion: tone == NoticeTone.error,
      child: Container(
        width: double.infinity,
        padding: context.padSym(h: Insets.x3, v: Insets.x2h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon ?? glyph,
              size: context.r(IconSz.xs),
              fill: 1,
              color: foreground,
            ),
            context.gapW(Insets.x2),
            Expanded(
              child: Text(
                text,
                style: context.text.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
