import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../extensions/context_extensions.dart';

/// A compact action: an icon over a short label, for the secondary actions of
/// a toolbar (reschedule, photo, attachment, cancel).
///
/// Four full-width buttons stacked for those took half a phone's height on the
/// visit screen, leaving the visit itself a sliver above them. Side by side as
/// tools they take one row, and the screen's primary action keeps the full
/// width.
class AppToolButton extends StatelessWidget {
  final String label;
  final IconData icon;

  /// Null renders the tool disabled.
  final VoidCallback? onPressed;

  /// Replaces the icon with a spinner and ignores taps.
  final bool loading;

  /// Tints the icon and label with the error colour (a cancel action).
  final bool destructive;

  const AppToolButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  /// Two lines before the label is cut: long translations wrap first.
  static const int _labelLines = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !loading;
    final base = destructive ? colors.error : colors.primary;
    final fg = enabled ? base : colors.onSurface.withValues(alpha: Alphas.disabled);
    final glyph = context.r(IconSz.md);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        onTap: enabled ? onPressed : null,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: IconSz.hit,
              minHeight: IconSz.hit,
            ),
            child: Padding(
              padding: context.padSym(h: Insets.x1, v: Insets.x1h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: glyph,
                    child: loading
                        ? Padding(
                            padding: context.padAll(Insets.x1),
                            child: CircularProgressIndicator(
                              strokeWidth: CompSz.buttonSpinnerStroke,
                              color: base,
                            ),
                          )
                        : Icon(icon, size: glyph, color: fg),
                  ),
                  context.gapH(Insets.x1),
                  Text(
                    label,
                    maxLines: _labelLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
