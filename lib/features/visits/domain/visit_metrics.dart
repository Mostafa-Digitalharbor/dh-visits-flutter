// visit_metrics.dart — pure aggregations over a list of [Visit].
//
// The dashboard and analytics screens used to derive every number inline in
// `build()`: each KPI tile, leaderboard, weekly bar and employee row ran its
// own `visits.where(...)` pass. On a 200-row team scope that was ~10 full
// sweeps (plus a `DateTime` allocation per row per sweep) on *every* rebuild —
// and a rebuild happens on each bloc emit, each theme change and each frame the
// pull-to-refresh indicator moves. It also meant the arithmetic could only be
// verified by pumping a widget.
//
// Everything here is a plain value type built in a single pass and covered by
// unit tests, so the widgets are left doing nothing but layout.
import '../../../core/utils/distance.dart';
import '../data/models/visit.dart';

/// A ranked `name → count` row for the dashboard leaderboards.
class LeaderboardEntry {
  final String name;
  final int count;

  const LeaderboardEntry(this.name, this.count);
}

/// One employee's punctuality row on the analytics screen.
class EmployeeOnTime {
  final String name;
  final int onTimePct;
  final int visits;

  const EmployeeOnTime({
    required this.name,
    required this.onTimePct,
    required this.visits,
  });
}

/// `true` when [a] and [b] fall on the same calendar day. Both are compared in
/// local time, which is what the user's "today" means.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sorts [counts] highest-first and keeps the top [limit] rows.
List<LeaderboardEntry> _rank(Map<String, int> counts, int limit) {
  final entries = counts.entries
      .map((e) => LeaderboardEntry(e.key, e.value))
      .toList(growable: false)
    ..sort((a, b) => b.count.compareTo(a.count));
  return entries.length <= limit ? entries : entries.sublist(0, limit);
}

/// Everything the manager dashboard renders, computed in one sweep.
class DashboardSummary {
  /// Scheduled day has passed with the visit still open.
  final int overdue;

  /// Sitting in any approval state.
  final int pendingReview;

  /// Scheduled / executed today.
  final int today;

  /// Currently checked in.
  final int activeNow;

  /// Today's finished visits, for the greeting's progress ring.
  final int todayDone;

  /// Denominator for that ring. Falls back to the whole list on a day with no
  /// visits so the ring reads `0 / total` rather than the meaningless `0 / 0`.
  final int todayTotal;

  /// Summed duration of every completed visit — the greeting's "field time".
  final int fieldMinutes;

  final List<LeaderboardEntry> topCustomers;

  /// Finished work only: a draft is a commitment, not a delivery.
  final List<LeaderboardEntry> topEmployees;

  const DashboardSummary({
    required this.overdue,
    required this.pendingReview,
    required this.today,
    required this.activeNow,
    required this.todayDone,
    required this.todayTotal,
    required this.fieldMinutes,
    required this.topCustomers,
    required this.topEmployees,
  });

  static const empty = DashboardSummary(
    overdue: 0,
    pendingReview: 0,
    today: 0,
    activeNow: 0,
    todayDone: 0,
    todayTotal: 0,
    fieldMinutes: 0,
    topCustomers: [],
    topEmployees: [],
  );

  /// Field time as hours with one decimal, dropping a trailing `.0`.
  String get fieldHoursLabel =>
      (fieldMinutes / 60).toStringAsFixed(fieldMinutes % 60 == 0 ? 0 : 1);

  /// [now] is injectable so the tests don't depend on the wall clock.
  factory DashboardSummary.from(List<Visit> visits, {DateTime? now, int topN = 5}) {
    final today = now ?? DateTime.now();
    var overdue = 0, pending = 0, todayCount = 0, active = 0;
    var todayDone = 0, minutes = 0;
    final customers = <String, int>{};
    final employees = <String, int>{};

    for (final v in visits) {
      if (v.isOverdue) overdue++;
      if (v.isAwaitingApproval) pending++;
      if (v.isInProgress) active++;

      final date = v.effectiveDate?.toLocal();
      final onToday = date != null && isSameDay(date, today);
      if (onToday) {
        todayCount++;
        if (v.isDone) todayDone++;
      }

      minutes += v.visitDuration?.inMinutes ?? 0;

      final customer = v.customerName;
      if (customer != null && customer.isNotEmpty) {
        customers[customer] = (customers[customer] ?? 0) + 1;
      }
      if (v.isDone) {
        final employee = v.employeeName;
        if (employee != null && employee.isNotEmpty) {
          employees[employee] = (employees[employee] ?? 0) + 1;
        }
      }
    }

    return DashboardSummary(
      overdue: overdue,
      pendingReview: pending,
      today: todayCount,
      activeNow: active,
      todayDone: todayDone,
      todayTotal: todayCount == 0 ? visits.length : todayCount,
      fieldMinutes: minutes,
      topCustomers: _rank(customers, topN),
      topEmployees: _rank(employees, topN),
    );
  }
}

/// Headline figures for one time window (this week / last week).
class WindowMetrics {
  /// Every visit in the window, not just the finished ones — this is the
  /// "visits this week" headline.
  final int count;

  /// Share of *completed* visits that ran on their scheduled day.
  final int onTimePct;

  /// Distance between consecutive check-in points, in whole km.
  final int km;

  final int avgMinutes;

  const WindowMetrics({
    required this.count,
    required this.onTimePct,
    required this.km,
    required this.avgMinutes,
  });

  static const empty =
      WindowMetrics(count: 0, onTimePct: 0, km: 0, avgMinutes: 0);

  factory WindowMetrics.from(List<Visit> visits) {
    var completed = 0, onTime = 0, durationCount = 0, durationMinutes = 0;
    final track = <Visit>[];

    for (final v in visits) {
      if (v.isDone) {
        completed++;
        if ((v.executionDaysDelta ?? 0) == 0) onTime++;
        final d = v.visitDuration;
        if (d != null) {
          durationCount++;
          durationMinutes += d.inMinutes;
        }
      }
      if (v.hasCheckInLocation) track.add(v);
    }

    track.sort((a, b) => (a.checkInTime ?? DateTime(0))
        .compareTo(b.checkInTime ?? DateTime(0)));
    var meters = 0.0;
    for (var i = 1; i < track.length; i++) {
      meters += haversineMeters(
        track[i - 1].checkInLat!,
        track[i - 1].checkInLng!,
        track[i].checkInLat!,
        track[i].checkInLng!,
      );
    }

    return WindowMetrics(
      count: visits.length,
      onTimePct: completed == 0 ? 0 : (onTime / completed * 100).round(),
      km: (meters / 1000).round(),
      avgMinutes:
          durationCount == 0 ? 0 : (durationMinutes / durationCount).round(),
    );
  }
}

/// Everything the analytics screen renders.
class AnalyticsSummary {
  final WindowMetrics current;
  final WindowMetrics previous;

  /// Seven daily counts, oldest first — the last entry is today.
  final List<int> weeklyCounts;

  /// The days those counts belong to, so the chart can label them.
  final List<DateTime> weeklyDays;

  final List<EmployeeOnTime> byEmployee;

  const AnalyticsSummary({
    required this.current,
    required this.previous,
    required this.weeklyCounts,
    required this.weeklyDays,
    required this.byEmployee,
  });

  /// Tallest bar in the weekly chart; `0` when there is no data at all.
  int get weeklyMax =>
      weeklyCounts.isEmpty ? 0 : weeklyCounts.reduce((a, b) => a > b ? a : b);

  /// Week-over-week change as a percentage. A jump from nothing is reported as
  /// +100% rather than a division by zero.
  static int pctDelta(num current, num previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return (((current - previous) / previous) * 100).round();
  }

  factory AnalyticsSummary.from(List<Visit> visits, {DateTime? now, int topN = 5}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final weekAgo = today.subtract(const Duration(days: 6));
    final prevStart = today.subtract(const Duration(days: 13));
    final prevEnd = today.subtract(const Duration(days: 7));

    final current = <Visit>[];
    final previous = <Visit>[];
    final weeklyDays =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final weeklyCounts = List.filled(7, 0);
    final byEmployee = <String, List<Visit>>{};

    for (final v in visits) {
      if (v.isDone) {
        final name = v.employeeName;
        if (name != null && name.isNotEmpty) {
          byEmployee.putIfAbsent(name, () => <Visit>[]).add(v);
        }
      }

      final local = v.effectiveDate?.toLocal();
      if (local == null) continue;
      final day = DateTime(local.year, local.month, local.day);

      if (!day.isBefore(weekAgo) && !day.isAfter(today)) {
        current.add(v);
        // `weekAgo` is exactly 6 days back, so this index is always 0..6.
        weeklyCounts[day.difference(weekAgo).inDays]++;
      } else if (!day.isBefore(prevStart) && !day.isAfter(prevEnd)) {
        previous.add(v);
      }
    }

    final rows = byEmployee.entries.map((e) {
      final onTime =
          e.value.where((v) => (v.executionDaysDelta ?? 0) == 0).length;
      return EmployeeOnTime(
        name: e.key,
        onTimePct: (onTime / e.value.length * 100).round(),
        visits: e.value.length,
      );
    }).toList()
      ..sort((a, b) => b.onTimePct.compareTo(a.onTimePct));

    return AnalyticsSummary(
      current: WindowMetrics.from(current),
      previous: WindowMetrics.from(previous),
      weeklyCounts: weeklyCounts,
      weeklyDays: weeklyDays,
      byEmployee: rows.length <= topN ? rows : rows.sublist(0, topN),
    );
  }
}
