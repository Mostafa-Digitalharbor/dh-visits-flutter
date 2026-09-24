import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/utils/communications.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';

/// One labelled value inside a [VisitSection] card: a tinted icon, a small
/// label above the value, and an optional trailing widget (e.g. an "open in
/// maps" button) or value colour (e.g. a warning).
class VisitDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;
  final Widget? trailing;

  /// When set, the whole row becomes tappable (e.g. the customer row opening
  /// the customer profile) and a chevron affordance is shown.
  final VoidCallback? onTap;

  const VisitDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tint = iconColor ?? cs.primary;
    // A caller's own trailing widget wins; a tappable row without one gets a
    // chevron so the tap target is visible rather than guessed at.
    final Widget? after = trailing ??
        (onTap == null
            ? null
            : Icon(
                // Mirrors itself in RTL (`matchTextDirection`). Picking
                // chevron_left for Arabic flipped it twice, so it pointed back.
                Icons.chevron_right,
                size: context.r(IconSz.sm),
                color: cs.onSurfaceVariant,
              ));
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: context.r(Insets.x2h)),
      child: MediaRow(
        leading: IconBadge(
          icon: icon,
          color: tint,
          size: context.r(CompSz.badge),
          iconSize: context.r(IconSz.label),
        ),
        trailing: after,
        trailingGap: trailing != null ? Insets.x2 : Insets.x1,
        // The value wraps rather than truncates: purpose, outcome and
        // addresses are the content the manager opened the screen to read.
        lines: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          context.gapH(Insets.hair),
          // In its own direction: an English purpose on an Arabic screen, or
          // an Arabic address on an English one.
          AutoDirectionText(
            value,
            style: context.text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.tile),
      onTap: onTap,
      child: row,
    );
  }
}

/// A compact "open in Maps" button for a coordinate.
///
/// The tinted badge is small, but the tap target around it is the full
/// [IconSz.hit] square — a field rep taps this one-handed.
class VisitMapsPill extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? label;

  const VisitMapsPill({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Never under the 48dp minimum: `r()` shrinks with the screen, and on a
    // 320dp phone the target came out at 41dp.
    final hit = math.max(kMinInteractiveDimension, context.r(IconSz.hit));
    return Tooltip(
      message: context.s.wfOpenInMaps,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.openExternal(
          () => Communications.openInMaps(latitude, longitude, label: label),
        ),
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: IconBadge(
              icon: Icons.map_outlined,
              color: context.colors.tertiary,
              size: context.r(CompSz.badge),
              iconSize: context.r(IconSz.label),
            ),
          ),
        ),
      ),
    );
  }
}
