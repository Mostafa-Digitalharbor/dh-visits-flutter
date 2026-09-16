import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/app_typography.dart';
import '../../app/design/responsive.dart';

/// A small tinted pill carrying a short label, optionally preceded by an icon —
/// visit state badges, role chips, category tags, "short visit" hints.
///
/// The five sites this replaces all drew the same shape (tinted background at a
/// low alpha, pill radius, bold small text in the tint colour) with slightly
/// different padding and font sizes. Those two knobs stay parameters because
/// they carry meaning: a state badge is the loudest thing in a card header, an
/// inline hint has to sit inside a row without pushing it taller.
///
/// The label is always `maxLines: 1` with an ellipsis. It is only wrapped in
/// [Flexible] when [flexibleLabel] is set, and that is deliberately opt-in: a
/// `Row` lays its non-flexible children out with an unbounded main-axis
/// constraint, so a pill dropped into one — the customer list's "last visit"
/// badge, for instance — would hit RenderFlex's "non-zero flex but incoming
/// width constraints are unbounded" assertion. Only the chip that has to be
/// squeezed by a header (where the parent does bound it) asks for it.
class TonePill extends StatelessWidget {
  final String label;

  /// Tints the background (at [tintAlpha]), the border and the text.
  final Color color;

  /// Optional leading glyph.
  final IconData? icon;

  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double tintAlpha;

  /// Null for no outline. The list-row "last visit" chip needs one because it
  /// sits on a card of nearly the same tone.
  final double? borderAlpha;

  /// Overrides the text/icon colour; needed by the chip that sits on the
  /// gradient header, where the tint is white and the foreground is too.
  final Color? foreground;

  final FontWeight fontWeight;

  /// Pill by default. The customer-list "last visit" chip is deliberately
  /// squarer so it reads as a data badge, not as a status pill.
  final double radius;

  /// See the class doc — only safe where the parent bounds this pill's width.
  final bool flexibleLabel;

  const TonePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = FontSz.sm,
    this.iconSize = IconSz.pill,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Insets.x2h,
      vertical: Insets.x1,
    ),
    this.tintAlpha = Alphas.tint,
    this.borderAlpha,
    this.foreground,
    this.fontWeight = FontWeight.w700,
    this.radius = Radii.pill,
    this.flexibleLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? color;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: fg),
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(radius),
        border: borderAlpha == null
            ? null
            : Border.all(color: color.withValues(alpha: borderAlpha!)),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, fill: 1, size: iconSize, color: fg),
                context.gapW(Insets.x1),
                if (flexibleLabel) Flexible(child: text) else text,
              ],
            ),
    );
  }
}
