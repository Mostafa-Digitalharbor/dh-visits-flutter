import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/utils/distance.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';
import '../../visits/data/models/visit.dart';

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
        final visits = state.items;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        List<Visit> window(int startDaysAgo, int endDaysAgo) {
          final start = today.subtract(Duration(days: startDaysAgo));
          final end = today.subtract(Duration(days: endDaysAgo));
          return visits.where((v) {
            final d = v.effectiveDate?.toLocal();
            if (d == null) return false;
            final day = DateTime(d.year, d.month, d.day);
            return !day.isBefore(start) && !day.isAfter(end);
          }).toList();
        }

        final cur = _Metrics.from(window(6, 0));
        final prev = _Metrics.from(window(13, 7));

        return ListView(
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
                  deltaUnit: '%',
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
                  deltaUnit: '%',
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
                  deltaUnit: '%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Symbols.timelapse,
                  tone: context.colors.tertiary,
                  value: cur.avgLabel,
                  label: context.s.analyticsAvgDuration,
                  delta: cur.avgMin - prev.avgMin,
                  deltaUnit: context.s.unitMinShort,
                  invertDelta: true,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _WeeklyChart(visits: visits),
            const SizedBox(height: 18),
            _SectionHead(icon: Symbols.leaderboard, label: context.s.analyticsByEmployee),
            const SizedBox(height: 10),
            _ByEmployee(visits: visits),
          ],
        );
      },
    );
  }

  static int _pctDelta(num cur, num prev) {
    if (prev == 0) return cur == 0 ? 0 : 100;
    return (((cur - prev) / prev) * 100).round();
  }
}

class _Metrics {
  final int count;
  final int onTimePct;
  final int km;
  final int avgMin;
  const _Metrics(this.count, this.onTimePct, this.km, this.avgMin);

  String get avgLabel {
    final h = (avgMin ~/ 60).toString().padLeft(2, '0');
    final m = (avgMin % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory _Metrics.from(List<Visit> visits) {
    final completed = visits.where((v) => v.isDone).toList();
    final onTime = completed.where((v) => (v.executionDaysDelta ?? 0) == 0).length;
    final pct = completed.isEmpty ? 0 : (onTime / completed.length * 100).round();
    // Field km — sum of distances between consecutive check-in points.
    final pts = visits
        .where((v) => v.hasCheckInLocation)
        .toList()
      ..sort((a, b) => (a.checkInTime ?? DateTime(0)).compareTo(b.checkInTime ?? DateTime(0)));
    double meters = 0;
    for (var i = 1; i < pts.length; i++) {
      meters += haversineMeters(
          pts[i - 1].checkInLat!, pts[i - 1].checkInLng!, pts[i].checkInLat!, pts[i].checkInLng!);
    }
    final durations = completed.where((v) => v.visitDuration != null).toList();
    final avgMin = durations.isEmpty
        ? 0
        : (durations.fold<int>(0, (s, v) => s + v.visitDuration!.inMinutes) / durations.length)
            .round();
    return _Metrics(visits.length, pct, (meters / 1000).round(), avgMin);
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(up ? Symbols.trending_up : Symbols.trending_down,
                      size: 15, color: deltaColor),
                  const SizedBox(width: 2),
                  Text('${up ? '+' : ''}$delta$deltaUnit',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: deltaColor)),
                ],
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
  final List<Visit> visits;
  const _WeeklyChart({required this.visits});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final x = context.x;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days.map((day) {
      return visits.where((v) {
        final d = v.effectiveDate?.toLocal();
        if (d == null) return false;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
    }).toList();
    final maxCount = (counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b));
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
              Text(context.s.analyticsWeeklyCompare,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: x.textTertiary)),
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
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: isToday ? cs.primary : x.textTertiary)),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: frac),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Container(
            width: 16,
            height: 8 + 80 * v,
            decoration: BoxDecoration(
              gradient: isToday ? x.avatarGradient : null,
              color: isToday ? null : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? cs.primary : x.textTertiary)),
      ],
    );
  }
}

class _ByEmployee extends StatelessWidget {
  final List<Visit> visits;
  const _ByEmployee({required this.visits});

  @override
  Widget build(BuildContext context) {
    final completed = visits.where((v) => v.isDone);
    final byEmp = <String, List<Visit>>{};
    for (final v in completed) {
      final name = v.employeeName;
      if (name == null || name.isEmpty) continue;
      byEmp.putIfAbsent(name, () => []).add(v);
    }
    final rows = byEmp.entries.map((e) {
      final onTime = e.value.where((v) => (v.executionDaysDelta ?? 0) == 0).length;
      final pct = (onTime / e.value.length * 100).round();
      return (name: e.key, pct: pct, visits: e.value.length);
    }).toList()
      ..sort((a, b) => b.pct.compareTo(a.pct));
    final shown = rows.take(5).toList();

    if (shown.isEmpty) {
      return AppCard(
        child: Row(children: [
          Icon(Symbols.inbox, color: context.x.textTertiary, size: 18),
          const SizedBox(width: 8),
          Text(context.s.dashboardNoData,
              style: TextStyle(color: context.colors.onSurfaceVariant)),
        ]),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _EmpRow(rank: i + 1, name: shown[i].name, pct: shown[i].pct, visits: shown[i].visits),
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
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
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
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
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
                  Text('$pct% · $visits',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tone,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
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

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHead({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 8),
        Text(label,
            style: AppType.titleSm.copyWith(fontWeight: FontWeight.w800, color: context.colors.onSurface)),
      ],
    );
  }
}
