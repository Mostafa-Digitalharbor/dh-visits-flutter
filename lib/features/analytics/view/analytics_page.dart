import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_decor.dart';
import '../../../app/theme.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/domain/visit_metrics.dart';
import '../../../core/utils/duration_format.dart';

/// Manager analytics (design screen 03). All metrics are derived from the
/// existing `VisitsListBloc` items — visits volume, on-time rate, field km
/// (from check-in coordinates), average duration, a weekly bar chart and a
/// per-employee on-time leaderboard.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisitsListBloc, VisitsListState>(
      builder: (context, state) {
        // This tab's bloc fetches when the tab is first opened, so the very
        // first frame has no data. Rendering the metric tiles then would show
        // a confident "0% on-time · 0 km" for as long as the request takes.
        if (state.items.isEmpty &&
            (state.status == VisitsListStatus.loading ||
                state.status == VisitsListStatus.initial)) {
          return const _AnalyticsSkeleton();
        }
        // Without this, a failed fetch renders every metric as 0% / 0 km with
        // confident-looking week-over-week deltas — fabricated analytics the
        // manager has no reason to distrust.
        if (state.status == VisitsListStatus.failure && state.items.isEmpty) {
          return ErrorView(
            message: state.error?.localize(context) ?? context.s.errUnknown,
            onRetry: () => context
                .read<VisitsListBloc>()
                .add(const VisitsListLoadRequested()),
          );
        }
        // One sweep builds this week's and last week's figures, the weekly
        // series and the employee table together — see [AnalyticsSummary].
        // Every tile below used to run its own pass over the full list on each
        // rebuild.
        final summary = AnalyticsSummary.from(state.items);
        final cur = summary.current;
        final prev = summary.previous;

        // Pull-to-refresh, matching the Dashboard. Without it this page had no
        // way to refetch at all — its bloc is built once and kept alive by the
        // shell's IndexedStack, so stale figures could only be cleared by
        // restarting the app.
        return AppRefreshIndicator(
          onRefresh: () async {
            final bloc = context.read<VisitsListBloc>();
            bloc.add(const VisitsListLoadRequested(scope: VisitListScope.team));
            await bloc.stream
                .firstWhere((s) => s.status != VisitsListStatus.loading);
          },
          child: ListView(
          padding: _pagePadding(context),
          children: [
            Row(children: [
              Expanded(
                child: _MetricTile(
                  icon: Symbols.verified,
                  tone: context.x.success,
                  value: '${cur.onTimePct}%',
                  label: context.s.analyticsOnTime,
                  delta: cur.onTimePct - prev.onTimePct,
                  deltaUnit: context.s.unitPercent,
                ),
              ),
              context.gapW(Insets.x3),
              Expanded(
                child: _MetricTile(
                  icon: Symbols.event_available,
                  tone: context.colors.primary,
                  value: '${cur.count}',
                  label: context.s.analyticsVisitsThisWeek,
                  delta: _pctDelta(cur.count, prev.count),
                  deltaUnit: context.s.unitPercent,
                ),
              ),
            ]),
            context.gapH(Insets.x3),
            Row(children: [
              Expanded(
                child: _MetricTile(
                  icon: Symbols.route,
                  tone: context.x.warning,
                  value: '${cur.km}',
                  label: context.s.analyticsKm,
                  delta: _pctDelta(cur.km, prev.km),
                  deltaUnit: context.s.unitPercent,
                ),
              ),
              context.gapW(Insets.x3),
              Expanded(
                child: _MetricTile(
                  icon: Symbols.timelapse,
                  tone: context.colors.tertiary,
                  value: Duration(minutes: cur.avgMinutes).clock,
                  label: context.s.analyticsAvgDuration,
                  delta: cur.avgMinutes - prev.avgMinutes,
                  deltaUnit: context.s.unitMinShort,
                  invertDelta: true,
                ),
              ),
            ]),
            context.gapH(Insets.x4),
            _WeeklyChart(summary: summary),
            context.gapH(Insets.x4h),
            SectionHeader(icon: Symbols.leaderboard, label: context.s.analyticsByEmployee),
            context.gapH(Insets.x2h),
            _ByEmployee(rows: summary.byEmployee),
          ],
          ),
        );
      },
    );
  }

  static int _pctDelta(num cur, num prev) => AnalyticsSummary.pctDelta(cur, prev);
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
    // Heights are the real components' measured heights, scaled the same way
    // they are, so the skeleton occupies exactly the box the content will.
    final tile = context.r(_tileHeight);
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
          SkeletonCard(height: context.r(_chartCardHeight)),
          context.gapH(Insets.x4h),
          SkeletonCard(height: context.r(_leaderboardHeight)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String value;
  final String label;
  final int delta;
  final String deltaUnit;
  final bool invertDelta;
  const _MetricTile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.delta,
    required this.deltaUnit,
    this.invertDelta = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final good = invertDelta ? delta <= 0 : delta >= 0;
    final deltaColor = good ? x.success : cs.error;
    final up = delta >= 0;
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
              const Spacer(),
              // On a 320dp screen these tiles are ~140dp wide, and a
              // three-digit delta ("+100%") next to the 38dp icon badge does
              // not fit: the Spacer collapses to zero and the row overflows.
              //
              // `FittedBox`, not an ellipsis. Ellipsising is safe but useless
              // here — "+…" tells the manager nothing, and a delta that cannot
              // be read may as well not be drawn. Scaling the whole chip down
              // keeps the number legible on the phones that need it while
              // leaving it at full size everywhere else.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(up ? Symbols.trending_up : Symbols.trending_down,
                          size: IconSz.pill, color: deltaColor),
                      context.gapW(Insets.hair),
                      Text('${up ? '+' : ''}$delta$deltaUnit',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: FontSz.sm,
                              fontWeight: FontWeight.w700,
                              color: deltaColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          context.gapH(Insets.x3),
          CountUpText(value,
              style: AppType.number(FontSz.metric, cs.onSurface)
                  .copyWith(height: 1)),
          context.gapH(Insets.x1),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: FontSz.sm, fontWeight: FontWeight.w500, color: x.textTertiary)),
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
    final days = summary.weeklyDays;
    final counts = summary.weeklyCounts;
    final maxCount = summary.weeklyMax;
    // Indexed by DateTime.weekday % 7 (Sun = 0 … Sat = 6), localised via l10n.
    final s = context.s;
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
                child: Text(context.s.analyticsWeeklyTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              context.gapW(Insets.x2),
              // Flexible even though it already ellipsizes: a Row measures its
              // inflexible children at their intrinsic width first, so on a
              // narrow card this subtitle claimed more than was left and the
              // Expanded title above it could not give any more back.
              Flexible(
                child: Text(context.s.analyticsWeeklyCompare,
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
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Bar(
                      count: counts[i],
                      maxCount: maxCount,
                      label: names[days[i].weekday % 7],
                      isToday: i == 6,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$count',
            maxLines: 1,
            style: TextStyle(
                fontSize: FontSz.sm, fontWeight: FontWeight.w800, color: isToday ? cs.primary : x.textTertiary)),
        context.gapH(Insets.x1h),
        // The bar takes whatever the two labels leave rather than a hardcoded
        // 8 + 80·v. Those fixed numbers plus the labels' own line heights added
        // up to just over the chart's 148dp box — a one-pixel overflow at the
        // default font scale, and a real clip at 1.25×. Now the column can
        // never exceed its parent whatever the font metrics do.
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: AppDurations.barGrow,
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              // The floor keeps an empty day visible as a stub rather than
              // vanishing, which is what the old `8 +` term was for.
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
            style: TextStyle(
                fontSize: FontSz.tiny,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? cs.primary : x.textTertiary)),
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
    final shown = rows;

    if (shown.isEmpty) {
      // Was a hand-rolled copy of this row whose Text had no Expanded, so the
      // Arabic "no data" sentence overflowed the card. [InlineEmptyRow] exists
      // precisely because four other screens made the same mistake.
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
          for (var i = 0; i < shown.length; i++)
            _EmpRow(
                rank: i + 1,
                name: shown[i].name,
                pct: shown[i].onTimePct,
                visits: shown[i].visits),
        ],
      ),
    );
  }
}

/// At or above this on-time percentage an employee's bar turns green; below it,
/// amber. Matches the threshold the Dashboard's leaderboard uses.
const int _onTimeGoodPct = 90;

class _EmpRow extends StatelessWidget {
  final int rank;
  final String name;
  final int pct;
  final int visits;
  const _EmpRow({required this.rank, required this.name, required this.pct, required this.visits});

  @override
  Widget build(BuildContext context) {
    final x = context.x;
    final tone = pct >= _onTimeGoodPct ? x.success : x.warning;
    return LeaderboardRow(
      leading: RankMedalAvatar(name: name, rank: rank),
      name: name,
      // The rate and the sample size together: 100% off two visits is not the
      // same result as 100% off forty, and the manager needs both to read the
      // board correctly.
      figure: '$pct${context.s.unitPercent} · $visits',
      value: pct / 100,
      color: tone,
      placement: LeaderFigurePlacement.inline,
    );
  }
}
