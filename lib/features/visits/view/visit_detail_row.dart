import 'package:flutter/material.dart';

import '../../../app/design/responsive.dart';

import '../../../app/design/app_dimens.dart';
import '../../../core/utils/communications.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';

/// A titled group: a small header (icon + label) above a card of [rows].
/// widget (e.g. an "open in maps" button) and value color (e.g. a warning).
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
  const VisitDetailRow({super.key, 
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
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconBadge(icon: icon, color: tint),
          context.gapW(Insets.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
                context.gapH(Insets.hair),
                Text(
                  value,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[context.gapW(Insets.x2), trailing!],
          if (onTap != null && trailing == null) ...[
            context.gapW(Insets.x1),
            Icon(
              context.isRtl ? Icons.chevron_left : Icons.chevron_right,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
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

/// A compact "open in Maps" pill button for a coordinate.
class VisitMapsPill extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? label;
  const VisitMapsPill({super.key, 
    required this.latitude,
    required this.longitude,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Tooltip(
      message: context.s.wfOpenInMaps,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.tile),
        onTap: () => context.openExternal(
            () => Communications.openInMaps(latitude, longitude, label: label)),
        child: IconBadge(
          icon: Icons.map_outlined,
          color: cs.tertiary,
          size: null,
          padding: const EdgeInsets.all(8),
          iconSize: 18,
          tintAlpha: 0.14,
        ),
      ),
    );
  }
}

