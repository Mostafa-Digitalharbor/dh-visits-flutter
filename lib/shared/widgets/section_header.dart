import 'package:flutter/material.dart';

import '../../app/design/app_dimens.dart';
import '../../app/design/app_typography.dart';
import '../../app/design/responsive.dart';
import '../extensions/context_extensions.dart';

/// Small heading above a card or list section.
///
/// Two variants, because the app uses two: an icon + bold title (dashboard,
/// analytics, visit sections) and an uppercase letter-spaced eyebrow (customer
/// detail, settings). Each existed as its own private class in two different
/// files, which is how one copy ended up with the `Flexible` that stops a long
/// Arabic title overflowing and the other didn't.
class SectionHeader extends StatelessWidget {
  final String label;

  /// Leading glyph, tinted with the primary colour. Omitted by [eyebrow].
  final IconData? icon;

  /// Optional trailing affordance — a count badge, a "see all" link.
  final Widget? trailing;

  /// Uppercase, letter-spaced, no icon.
  final bool isEyebrow;

  /// Eyebrow only. Each caller sits above a different kind of block (a settings
  /// group card, a customer-detail field list) and wants its own gap.
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
  })  : isEyebrow = false,
        padding = EdgeInsets.zero;

  const SectionHeader.eyebrow({
    super.key,
    required this.label,
    this.padding = EdgeInsets.zero,
  })  : icon = null,
        trailing = null,
        isEyebrow = true;

  /// Letter spacing of the eyebrow in Latin script. Arabic letters join, and
  /// spacing them apart breaks the word, so RTL gets none.
  static const double _eyebrowTracking = 1.0;

  @override
  Widget build(BuildContext context) {
    if (isEyebrow) {
      return Padding(
        padding: padding,
        child: Text(
          label.toUpperCase(),
          // AppType.eyebrow is the theme's labelSmall — the two private copies
          // this replaced reached the same style from opposite directions, one
          // via the token and one via `context.text.labelSmall`.
          style: AppType.eyebrow.copyWith(
            color: context.colors.primary,
            letterSpacing: context.isRtl ? 0 : _eyebrowTracking,
          ),
        ),
      );
    }
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: context.r(IconSz.label), color: context.colors.primary),
          context.gapW(Insets.x2),
        ],
        // Expanded + ellipsis: these are localized titles that run longer in
        // Arabic and grow with the OS text scale. Expanded, not Flexible with a
        // Spacer after it — the two split the row in half, so a long title was
        // cut at half width even beside a two-digit badge.
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) ...[
          context.gapW(Insets.x2),
          trailing!,
        ],
      ],
    );
  }
}
