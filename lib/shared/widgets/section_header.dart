import 'package:flutter/material.dart';

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

  const SectionHeader({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
  }) : isEyebrow = false;

  const SectionHeader.eyebrow({super.key, required this.label})
      : icon = null,
        trailing = null,
        isEyebrow = true;

  @override
  Widget build(BuildContext context) {
    if (isEyebrow) {
      return Text(
        label.toUpperCase(),
        style: context.text.labelMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      );
    }
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
        ],
        // Flexible + ellipsis: these are localized titles that run longer in
        // Arabic and grow with the OS text scale.
        Flexible(
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
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}
