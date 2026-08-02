import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
              const SizedBox(width: 12),
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
            const SizedBox(height: 12),
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
              const SizedBox(width: 12),
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
            const SizedBox(height: 16),
            _WeeklyChart(summary: summary),
            const SizedBox(height: 18),
            SectionHeader(icon: Symbols.leaderboard, label: context.s.analyticsByEmployee),
            const SizedBox(height: 10),
            _ByEmployee(rows: summary.byEmployee),
          ],
          ),
        );
      },
    );
  }

  static int _pctDelta(num cur, num prev) => AnalyticsSummary.pctDelta(cur, prev);
}

/// Matches the real layout's rhythm — two tile rows, the weekly chart, then the
/// employee table — so the screen doesn't jump when the data lands.
class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: const [
          Row(children: [
            Expanded(child: SkeletonCard(height: 104)),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard(height: 104)),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: SkeletonCard(height: 104)),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard(height: 104)),
          ]),
          SizedBox(height: 16),
          SkeletonCard(height: 220),
          SizedBox(height: 18),
          SkeletonCard(height: 240),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: x.outlineVariant),
        boxShadow: x.elev1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(icon, fill: 1, size: 20, color: tone),
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
                          size: 15, color: deltaColor),
                      const SizedBox(width: 2),
                      Text('${up ? '+' : ''}$delta$deltaUnit',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: deltaColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CountUpText(value, style: AppType.number(26, cs.onSurface).copyWith(height: 1)),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: x.textTertiary)),
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
              const SizedBox(width: 8),
              // Flexible even though it already ellipsizes: a Row measures its
              // inflexible children at their intrinsic width first, so on a
              // narrow card this subtitle claimed more than was left and the
              // Expanded title above it could not give any more back.
              Flexible(
                child: Text(context.s.analyticsWeeklyCompare,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: x.textTertiary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 148,
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
                fontSize: 12, fontWeight: FontWeight.w800, color: isToday ? cs.primary : x.textTertiary)),
        const SizedBox(height: 6),
        // The bar takes whatever the two labels leave rather than a hardcoded
        // 8 + 80·v. Those fixed numbers plus the labels' own line heights added
        // up to just over the chart's 148dp box — a one-pixel overflow at the
        // default font scale, and a real clip at 1.25×. Now the column can
        // never exceed its parent whatever the font metrics do.
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              // Floor of 0.09 keeps an empty day visible as a stub rather than
              // vanishing, which is what the old `8 +` term was for.
              heightFactor: (0.09 + 0.91 * v).clamp(0.0, 1.0),
              child: Container(
                width: 16,
                decoration: BoxDecoration(
                  gradient: isToday ? x.avatarGradient : null,
                  color: isToday ? null : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            maxLines: 1,
            style: TextStyle(
                fontSize: 10,
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
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _EmpRow(
                rank: i + 1,
                name: shown[i].name,
                pct: shown[i].onTimePct,
                visits: shown[i].visits),
          ],
        ],
      ),
    );
  }
}

class _EmpRow extends StatelessWidget {
  final int rank;
  final String name;
  final int pct;
  final int visits;
  const _EmpRow({required this.rank, required this.name, required this.pct, required this.visits});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final tone = pct >= 90 ? x.success : x.warning;
    final medal = switch (rank) {
      1 => const Color(0xFFD9A40C),
      2 => const Color(0xFF9AA0B4),
      3 => const Color(0xFFB87333),
      _ => cs.onSurfaceVariant,
    };
    // Ranks 1-3 sit on fixed medal hues that pair with white. Rank 4+ falls
    // back to the theme-adaptive onSurfaceVariant, which is light in dark mode
    // — so white text would vanish there. Use the surface tone (its inverse)
    // for those so the number stays legible in both themes.
    final medalText = rank <= 3 ? Colors.white : cs.surface;
    final initial = InitialAvatar.initialOf(name);
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: x.avatarGradient, shape: BoxShape.circle),
              child: Text(initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            PositionedDirectional(
              end: -2,
              top: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medal,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surfaceContainerLowest, width: 2),
                ),
                child: Text('$rank',
                    style: TextStyle(color: medalText, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.titleSm.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface)),
                  ),
                  Text('$pct${context.s.unitPercent} · $visits',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tone,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.badge),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (pct / 100).clamp(0, 1),
                  backgroundColor: cs.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(tone),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
