import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/utils/app_number.dart';
import '../../../core/utils/duration_format.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../dashboard/view/visits_list_feedback.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/domain/visit_metrics.dart';
import 'metric_tile.dart';

/// Manager analytics (design screen 03). All metrics are derived from the
/// existing `VisitsListBloc` items — visits volume, on-time rate, field km
/// (from check-in coordinates), average duration, a weekly bar chart and a
/// per-employee on-time leaderboard.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  /// Pull-to-refresh, matching the Dashboard. Its bloc is built once and kept
  /// alive by the shell's stack, so without this stale figures could only be
  /// cleared by switching tabs. The spinner lasts as long as the reload.
  static Future<void> _refresh(BuildContext context) {
    final bloc = context.read<VisitsListBloc>()
      ..add(const VisitsListLoadRequested(scope: VisitListScope.team));
    return bloc.untilSettled((s) => s.status == VisitsListStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    return VisitsRefreshFailureListener(
      child: BlocBuilder<VisitsListBloc, VisitsListState>(
        builder: (context, state) {
          // This tab's bloc fetches when the tab is first opened, so the very
          // first frame has no data. Rendering the metric tiles then would
          // show a confident "0% on-time · 0 km" for as long as the request
          // takes.
          if (state.items.isEmpty &&
              (state.status == VisitsListStatus.loading ||
                  state.status == VisitsListStatus.initial)) {
            return const _AnalyticsSkeleton();
          }
          // Without this, a failed fetch renders every metric as 0% / 0 km
          // with confident-looking week-over-week deltas — fabricated
          // analytics the manager has no reason to distrust.
          if (state.status == VisitsListStatus.failure && state.items.isEmpty) {
            return ErrorView(
              message: state.error?.localize(context) ?? context.s.errUnknown,
              onRetry: () => _refresh(context),
            );
          }
          // One sweep builds this week's and last week's figures, the weekly
          // series and the employee table together — see [AnalyticsSummary].
          final summary = AnalyticsSummary.from(state.items);
          return AppRefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView(
              padding: _pagePadding(context),
              children: [
                _MetricGrid(summary: summary),
                context.gapH(Insets.x4),
                _WeeklyChart(summary: summary),
                context.gapH(Insets.x4h),
                SectionHeader(
                  icon: Symbols.leaderboard,
                  label: context.s.analyticsByEmployee,
                ),
                context.gapH(Insets.x2h),
                _ByEmployee(rows: summary.byEmployee),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shared by the page and its skeleton so the two cannot drift — the whole
/// point of the skeleton is that the real content lands in the same place.
/// The extra bottom inset clears the shell's nav bar.
EdgeInsets _pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
      context.r(Insets.screen),
      context.r(Insets.screen),
      context.r(Insets.screen),
      context.rh(Insets.x6 + Insets.x1),
    );

/// The four headline tiles, two per row.
class _MetricGrid extends StatelessWidget {
  final AnalyticsSummary summary;
  const _MetricGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final cur = summary.current;
    final prev = summary.previous;
    String percentChange(num change) =>
        s.unitPercentValue(AppNumber.signed(change));
    final countChange = AnalyticsSummary.pctDelta(cur.count, prev.count);
    final kmChange = AnalyticsSummary.pctDelta(cur.km, prev.km);
    final onTimeChange = cur.onTimePct - prev.onTimePct;
    final durationChange = cur.avgMinutes - prev.avgMinutes;

    return Column(
      children: [
        MetricTileRow(
          start: MetricTile(
            icon: Symbols.verified,
            tone: context.x.success,
            value: AppNumber.percent(s, cur.onTimePct),
            label: s.analyticsOnTime,
            countUp: true,
            delta: MetricDelta(
              change: onTimeChange,
              text: percentChange(onTimeChange),
            ),
          ),
          end: MetricTile(
            icon: Symbols.event_available,
            tone: context.colors.primary,
            value: AppNumber.whole(cur.count),
            label: s.analyticsVisitsThisWeek,
            countUp: true,
            delta: MetricDelta(
              change: countChange,
              text: percentChange(countChange),
            ),
          ),
        ),
        context.gapH(Insets.x3),
        MetricTileRow(
          start: MetricTile(
            icon: Symbols.route,
            tone: context.x.warning,
            value: AppNumber.whole(cur.km),
            label: s.analyticsKm,
            countUp: true,
            delta: MetricDelta(
              change: kmChange,
              text: percentChange(kmChange),
            ),
          ),
          end: MetricTile(
            icon: Symbols.timelapse,
            tone: context.colors.tertiary,
            value: Duration(minutes: cur.avgMinutes).clock,
            label: s.analyticsAvgDuration,
            delta: MetricDelta(
              change: durationChange,
              text: s.unitMinutes(AppNumber.signed(durationChange)),
              // A shorter average visit is the good news.
              higherIsBetter: false,
            ),
          ),
        ),
      ],
    );
  }
}

// Placeholder heights for [_AnalyticsSkeleton], named so the relationship to
// the components they stand in for is stated rather than implied by a literal.

/// A metric tile: badge row + 26dp number + caption, inside 14dp padding.
const double _tileHeight = 104.0;

/// The weekly card: title row + [CompSz.chartHeight] plot + card padding.
const double _chartCardHeight = 220.0;

/// Five leaderboard rows at ~42dp plus the gaps between them.
const double _leaderboardHeight = 240.0;

/// Matches the real layout's rhythm — two tile rows, the weekly chart, then the
/// employee table — so the screen doesn't jump when the data lands.
class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    // Heights follow the text scale the way the real tiles grow with it.
    final tile = context.fixedH(_tileHeight);
    final gap = context.gapW(Insets.x3);
    final tileRow = Row(children: [
      Expanded(child: SkeletonCard(height: tile)),
      gap,
      Expanded(child: SkeletonCard(height: tile)),
    ]);
    return AppShimmer(
      child: ListView(
        padding: _pagePadding(context),
        children: [
          tileRow,
          context.gapH(Insets.x3),
          tileRow,
          context.gapH(Insets.x4),
          SkeletonCard(height: context.fixedH(_chartCardHeight)),
          context.gapH(Insets.x4h),
          SkeletonCard(height: context.fixedH(_leaderboardHeight)),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final AnalyticsSummary summary;
  const _WeeklyChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final s = context.s;
    final days = summary.weeklyDays;
    final counts = summary.weeklyCounts;
    final maxCount = summary.weeklyMax;
    // Indexed by DateTime.weekday % daysPerWeek (Sun = 0 … Sat = 6).
    final names = [
      s.weekdayShortSun,
      s.weekdayShortMon,
      s.weekdayShortTue,
      s.weekdayShortWed,
      s.weekdayShortThu,
      s.weekdayShortFri,
      s.weekdayShortSat,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.analyticsWeeklyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titleSm.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              context.gapW(Insets.x2),
              // Flexible even though it already ellipsizes: a Row measures its
              // inflexible children at their intrinsic width first, so on a
              // narrow card this subtitle claimed more than was left and the
              // Expanded title above it could not give any more back.
              Flexible(
                child: Text(s.analyticsWeeklyCompare,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: FontSz.sm, color: x.textTertiary)),
              ),
            ],
          ),
          context.gapH(Insets.x4),
          SizedBox(
            // fixedH, not r(): the box wraps two text labels, and text does
            // not shrink on a narrow phone — scaling this by width clipped
            // them on exactly the 320dp screens that need the room. Growth is
            // one-way, so a large font setting makes the plot taller and never
            // shorter than its design height.
            height: context.fixedH(CompSz.chartHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < counts.length && i < days.length; i++)
                  Expanded(
                    child: _Bar(
                      count: counts[i],
                      maxCount: maxCount,
                      label: names[days[i].weekday % DateTime.daysPerWeek],
                      // The series is oldest first; the last day is today.
                      isToday: i == days.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fraction of the plot height a zero-count day still occupies, so a quiet day
/// reads as "nothing happened" rather than as a missing bar.
const double _barFloor = 0.09;

class _Bar extends StatelessWidget {
  final int count;
  final int maxCount;
  final String label;
  final bool isToday;
  const _Bar({required this.count, required this.maxCount, required this.label, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final frac = maxCount == 0 ? 0.0 : count / maxCount;
    final tone = isToday ? cs.primary : x.textTertiary;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(AppNumber.whole(count),
            maxLines: 1,
            style: TextStyle(
                fontSize: FontSz.sm, fontWeight: FontWeight.w800, color: tone)),
        context.gapH(Insets.x1h),
        // The bar takes whatever the two labels leave rather than a fixed
        // height, so the column can never exceed its parent whatever the font
        // metrics do.
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: AppDurations.barGrow,
            curve: AppCurves.decelerate,
            builder: (_, v, __) => FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              // The floor keeps an empty day visible as a stub rather than
              // vanishing.
              heightFactor:
                  (_barFloor + (1 - _barFloor) * v).clamp(0.0, 1.0),
              child: Container(
                width: context.r(CompSz.chartBar),
                decoration: BoxDecoration(
                  gradient: isToday ? x.avatarGradient : null,
                  color: isToday ? null : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
              ),
            ),
          ),
        ),
        context.gapH(Insets.x2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
                fontSize: FontSz.tiny,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: tone)),
      ],
    );
  }
}

class _ByEmployee extends StatelessWidget {
  /// Already ranked and truncated — see [AnalyticsSummary].
  final List<EmployeeOnTime> rows;
  const _ByEmployee({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppCard(
        child: InlineEmptyRow(
          icon: Symbols.inbox,
          text: context.s.dashboardNoData,
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _EmpRow(rank: i + 1, row: rows[i]),
        ],
      ),
    );
  }
}

/// At or above this on-time percentage an employee's bar turns green; below it,
/// amber.
const int _onTimeGoodPct = 90;

/// The top of the on-time scale, for the bar fraction.
const int _fullPct = 100;

class _EmpRow extends StatelessWidget {
  final int rank;
  final EmployeeOnTime row;
  const _EmpRow({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final x = context.x;
    final tone = row.onTimePct >= _onTimeGoodPct ? x.success : x.warning;
    return LeaderboardRow(
      leading: RankMedalAvatar(name: row.name, rank: rank),
      name: row.name,
      // The rate and the sample size together: 100% off two visits is not the
      // same result as 100% off forty, and the manager needs both to read the
      // board correctly. The count stays a bare number: the figure cannot
      // shrink in this row, and "12 visits" beside a long Arabic name
      // overflows a 320dp phone.
      figure: context.joinFacts([
        AppNumber.percent(s, row.onTimePct),
        AppNumber.whole(row.visits),
      ]),
      value: row.onTimePct / _fullPct,
      color: tone,
      placement: LeaderFigurePlacement.inline,
    );
  }
}
