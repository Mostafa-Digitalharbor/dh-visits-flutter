import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/data/models/visit.dart';
import '../../visits/view/visit_labels.dart';
import '../bloc/day_trails_cubit.dart';
import 'route_map.dart';

/// Section title on the route list.
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.titleSm.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colors.onSurface,
        ),
      );
}

/// A failure inside the route list, with the way out next to it.
///
/// The in-list counterpart of [StatusBanner]: that strip spans the screen
/// under the app bar, while these sit between the list's own sections and
/// scroll with them — a banner above a map would eat a landscape screen.
class RouteNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const RouteNotice({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      margin: EdgeInsets.only(bottom: context.rh(Insets.x3)),
      padding: EdgeInsetsDirectional.fromSTEB(
        context.r(Insets.x3),
        context.r(Insets.x2),
        context.r(Insets.x1),
        context.r(Insets.x2),
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: Alphas.soft),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(Symbols.error, size: context.r(IconSz.label), color: cs.error),
          context.gapW(Insets.x2),
          Expanded(
            // Side by side while both fit; otherwise the button drops under
            // the message. In one Row the button could not give way, and a
            // long Arabic reason pushed its label off a small phone's edge.
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.start,
              children: [
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: Text(context.s.commonRetry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One visit on the day's lists: a leading mark keyed to the map, the visit,
/// a recorded-route summary, and a tap through to the visit's own trail.
class RouteVisitRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String summary;
  final VoidCallback onTap;

  const RouteVisitRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: onTap,
      child: Padding(
        padding: context.padSym(v: Insets.x2),
        child: Row(
          children: [
            leading,
            context.gapW(Insets.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoDirectionText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titleSm.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  context.gapH(Insets.x1),
                  // Composed with joinFacts: follows the screen direction.
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: FontSz.sm,
                        fontWeight: FontWeight.w600,
                        color: x.textTertiary),
                  ),
                ],
              ),
            ),
            context.gapW(Insets.x2),
            Flexible(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: FontSz.sm,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant),
              ),
            ),
            // Mirrors itself in RTL.
            Icon(Symbols.chevron_right,
                size: context.r(IconSz.md), color: x.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// "12 points · 3.4 km".
String _trailSummary(BuildContext context, int points, double km) {
  final s = context.s;
  return context.joinFacts(
      [s.routePointsCount(points), AppNumber.km(s, km, precise: true)]);
}

/// The day's recorded visit trails, one row per visit in the order they were
/// done, each keyed to its line on the map by colour and opening that visit's
/// own full trail.
class RecordedTrailsSection extends StatelessWidget {
  final List<DayTrail> trails;

  /// How many of the day's visits could not be read.
  final int failed;
  final VoidCallback onRetry;

  const RecordedTrailsSection({
    super.key,
    required this.trails,
    required this.failed,
    required this.onRetry,
  });

  /// The colour bar that keys a row to its line on the map.
  static const double _barWidth = Insets.x1h;
  static const double _barHeight = Insets.x10;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final tf = AppDate.timeFormat(context);
    String time(DateTime? utc) =>
        utc == null ? s.commonNoValue : tf.format(context.toUserTime(utc));

    return Padding(
      padding: EdgeInsets.only(top: context.rh(Insets.x2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trails.isNotEmpty) ...[
            _SectionTitle(s.routeRecordedTrails),
            context.gapH(Insets.x2),
          ],
          for (var i = 0; i < trails.length; i++)
            RouteVisitRow(
              leading: Container(
                width: context.r(_barWidth),
                // fixedH: the bar spans a two-line text block, which grows
                // with the font size.
                height: context.fixedH(_barHeight),
                decoration: BoxDecoration(
                  color: AppColors.routePaletteAt(i),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              title: trails[i].visit.displayTitle(context),
              subtitle: context.joinFacts([
                trails[i].visit.name,
                s.commonTimeRange(
                  time(trails[i].visit.startDatetime),
                  time(trails[i].visit.endDatetime),
                ),
              ]),
              summary: _trailSummary(
                context,
                trails[i].track.locationLogCount,
                trails[i].track.trackedDistanceKm,
              ),
              onTap: () => context.push(
                AppRoutes.visitTrail(trails[i].visit.id),
                extra: trails[i].visit,
              ),
            ),
          if (failed > 0)
            Padding(
              padding: EdgeInsets.only(top: context.rh(Insets.x1)),
              child: RouteNotice(
                message: s.routeTrailsLoadFailed(failed),
                onRetry: onRetry,
              ),
            ),
        ],
      ),
    );
  }
}

/// One planned stop on today's timeline: its number (the same pin as on the
/// map), the customer, the planned time and the drive from the previous stop.
class RouteStopRow extends StatelessWidget {
  final int index;
  final Visit visit;
  final bool isNext;
  final bool isLast;

  /// Estimated drive from the previous stop; null for the first.
  final int? driveMinutes;

  const RouteStopRow({
    super.key,
    required this.index,
    required this.visit,
    required this.isNext,
    required this.isLast,
    required this.driveMinutes,
  });

  /// The line joining one stop's pin to the next.
  static const double _connectorWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cs = context.colors;
    final x = context.x;
    final planned = visit.visitDate;
    // Odoo times are UTC; shown in the user's own timezone like everywhere
    // else (the raw value put the ETA hours off).
    final eta = planned == null
        ? s.commonNoValue
        : AppDate.timeFormat(context).format(context.toUserTime(planned));
    final metaStyle = TextStyle(
        fontSize: FontSz.sm, fontWeight: FontWeight.w600, color: x.textTertiary);
    final metaIcon = context.r(IconSz.inline);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isNext ? x.glowBrand : null,
                ),
                child: StopNumberPin(number: index + 1, isNext: isNext),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: _connectorWidth,
                    color: x.divider,
                    margin: context.padSym(v: Insets.x1),
                  ),
                ),
            ],
          ),
          context.gapW(Insets.x3),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () =>
                  context.push(AppRoutes.visitDetail(visit.id), extra: visit),
              child: Padding(
                padding: EdgeInsets.only(bottom: context.rh(Insets.x4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(visit.displayTitle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.titleSm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                        ),
                        if (isNext) ...[
                          context.gapW(Insets.x1),
                          TonePill(
                            label: s.routeNextStop,
                            color: cs.primary,
                            fontSize: FontSz.xs,
                            tintAlpha: Alphas.tint,
                            padding: context.padSym(h: Insets.x2, v: Insets.x1),
                          ),
                        ],
                      ],
                    ),
                    context.gapH(Insets.x1),
                    // Flexible + ellipsis on both labels: "09:30 · Start point"
                    // plus "25 min drive" already exceeds a 320dp row at the
                    // largest text scale, and Arabic runs longer still.
                    Row(
                      children: [
                        Icon(Symbols.schedule,
                            size: metaIcon, color: x.textTertiary),
                        context.gapW(Insets.x1),
                        Flexible(
                          child: Text(
                            index == 0
                                ? context.joinFacts([eta, s.routeStartPoint])
                                : eta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ),
                        if (driveMinutes case final minutes?) ...[
                          context.gapW(Insets.x2h),
                          Icon(Symbols.directions_car,
                              size: metaIcon, color: x.textTertiary),
                          context.gapW(Insets.x1),
                          Flexible(
                            child: Text(
                              s.routeDriveMinutes(minutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
