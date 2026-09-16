import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_decor.dart';
import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';

/// The change of a figure since the previous period.
class MetricDelta {
  /// Signed amount of the change; only its sign is read here.
  final num change;

  /// Already formatted, sign and unit included ("+5%", "−3 min").
  final String text;

  /// False when a smaller figure is the good news (a shorter average visit).
  final bool higherIsBetter;

  const MetricDelta({
    required this.change,
    required this.text,
    this.higherIsBetter = true,
  });

  bool get isFlat => change == 0;
  bool get isUp => change > 0;
  bool get isGood => higherIsBetter ? change > 0 : change < 0;
}

/// A headline figure on a panel: a tinted badge, the value, its caption and,
/// optionally, the change since the previous period.
///
/// Analytics shows four of these and the route screen two. They were separate
/// private tiles with different paddings and type sizes for the same idea.
class MetricTile extends StatelessWidget {
  final IconData icon;

  /// Tints the badge.
  final Color tone;
  final String value;
  final String label;
  final MetricDelta? delta;

  /// Counts the value up from zero on first build (plain integers and
  /// percentages only; anything else renders as is).
  final bool countUp;

  const MetricTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    this.delta,
    this.countUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final valueStyle =
        AppType.number(FontSz.metric, cs.onSurface).copyWith(height: 1);
    final change = delta;
    return Container(
      padding: context.padAll(Insets.x3h),
      decoration: AppDecor.panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: icon,
                color: tone,
                size: context.r(CompSz.badgeLg),
                iconSize: context.r(IconSz.sm),
                radius: Radii.sm,
                tintAlpha: Alphas.tintStrong,
                fill: 1,
              ),
              if (change != null) ...[
                const Spacer(),
                // On a 320dp screen these tiles are ~140dp wide, and a
                // three-digit delta ("+100%") next to the badge does not fit:
                // the Spacer collapses to zero and the row overflows.
                //
                // `FittedBox`, not an ellipsis. "+…" tells the manager
                // nothing; scaling the chip down keeps the number legible on
                // the phones that need it and full size everywhere else.
                Flexible(child: _DeltaChip(delta: change)),
              ],
            ],
          ),
          context.gapH(Insets.x3),
          // Scale down rather than wrap: a long formatted value ("1,234.5 km")
          // must stay one line in a half-width tile.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: countUp
                ? CountUpText(value, style: valueStyle)
                : Text(value, maxLines: 1, style: valueStyle),
          ),
          context.gapH(Insets.x1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: FontSz.sm,
              fontWeight: FontWeight.w500,
              color: x.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two [MetricTile]s side by side, sharing the width.
class MetricTileRow extends StatelessWidget {
  final Widget start;
  final Widget end;
  const MetricTileRow({super.key, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: start),
        context.gapW(Insets.x3),
        Expanded(child: end),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final MetricDelta delta;
  const _DeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    // No change is neither good nor bad news: neutral, with a flat arrow.
    final color = delta.isFlat
        ? context.x.textTertiary
        : delta.isGood
            ? context.x.success
            : context.colors.error;
    final arrow = delta.isFlat
        ? Symbols.trending_flat
        : delta.isUp
            ? Symbols.trending_up
            : Symbols.trending_down;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            arrow,
            size: IconSz.pill,
            color: color,
          ),
          context.gapW(Insets.hair),
          Text(
            delta.text,
            maxLines: 1,
            // The sign belongs to the number: kept left-to-right so "+5%"
            // does not render as "5%+" inside an Arabic row.
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: FontSz.sm,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
