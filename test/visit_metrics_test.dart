// Covers the aggregations the Dashboard and Analytics screens render.
//
// These numbers used to be computed inline in `build()`, where the only way to
// check them was to pump a widget and read pixels — so in practice they were
// never checked at all. They are the figures a manager makes staffing and
// escalation decisions on, and several have edge cases that silently produce a
// confident wrong answer: an on-time rate over zero completed visits, a
// week-over-week delta against a zero baseline, a leaderboard bar divided by an
// empty max.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/domain/visit_metrics.dart';

/// `now` for every test, so "today" is deterministic. Mid-afternoon so that
/// same-day offsets in either direction stay on the same date.
final _now = DateTime(2026, 7, 25, 14, 0);

DateTime _daysAgo(int n) => _now.subtract(Duration(days: n));

Visit _visit({
  int id = 1,
  VisitState state = VisitState.approved,
  DateTime? scheduled,
  DateTime? start,
  DateTime? end,
  String? partner,
  String? employee,
  double? startLat,
  double? startLng,
}) =>
    Visit(
      id: id,
      state: state,
      scheduledDatetime: scheduled,
      startDatetime: start,
      endDatetime: end,
      partnerName: partner,
      employeeName: employee,
      startLat: startLat,
      startLng: startLng,
    );

/// A visit completed on its scheduled day, [minutes] long.
Visit _done({
  required int id,
  required DateTime day,
  int minutes = 60,
  String? partner,
  String? employee,
  int scheduleOffsetDays = 0,
  double? lat,
  double? lng,
}) =>
    _visit(
      id: id,
      state: VisitState.done,
      scheduled: day.subtract(Duration(days: scheduleOffsetDays)),
      start: day,
      end: day.add(Duration(minutes: minutes)),
      partner: partner,
      employee: employee,
      startLat: lat,
      startLng: lng,
    );

void main() {
  group('DashboardSummary', () {
    test('an empty list produces zeros, not a crash or a divide-by-zero', () {
      final s = DashboardSummary.from(const [], now: _now);
      expect(s.overdue, 0);
      expect(s.pendingReview, 0);
      expect(s.today, 0);
      expect(s.activeNow, 0);
      expect(s.fieldMinutes, 0);
      expect(s.topCustomers, isEmpty);
      expect(s.topEmployees, isEmpty);
    });

    test('counts each KPI off the same single pass', () {
      final visits = [
        // Overdue: scheduled in the past, still open.
        _visit(id: 1, state: VisitState.approved, scheduled: _daysAgo(3)),
        _visit(id: 2, state: VisitState.approved, scheduled: _daysAgo(1)),
        // Awaiting approval.
        _visit(id: 3, state: VisitState.submitted, scheduled: _now),
        // Running right now.
        _visit(id: 4, state: VisitState.inProgress, start: _now),
        // Finished today.
        _done(id: 5, day: _now, minutes: 90),
      ];
      final s = DashboardSummary.from(visits, now: _now);

      expect(s.overdue, 2);
      expect(s.pendingReview, 1);
      // #3 (scheduled today), #4 (started today), #5 (ended today).
      expect(s.today, 3);
      expect(s.activeNow, 1);
      expect(s.todayDone, 1);
      expect(s.fieldMinutes, 90);
    });

    test('a completed visit is never counted as overdue', () {
      // A visit finished a week after it was booked is late, but it is not
      // outstanding work — showing it under "Overdue" sends a manager chasing
      // something already delivered.
      final visits = [
        _done(id: 1, day: _daysAgo(2), scheduleOffsetDays: 5),
      ];
      expect(DashboardSummary.from(visits, now: _now).overdue, 0);
    });

    test('field time renders whole hours without a trailing .0', () {
      final twoHours = [_done(id: 1, day: _now, minutes: 120)];
      expect(DashboardSummary.from(twoHours, now: _now).fieldHoursLabel, '2');

      final ninety = [_done(id: 1, day: _now, minutes: 90)];
      expect(DashboardSummary.from(ninety, now: _now).fieldHoursLabel, '1.5');
    });

    test('the greeting falls back to the whole list on a day with no visits',
        () {
      // Otherwise the progress ring reads "0 / 0", which renders as either a
      // full ring or a divide-by-zero depending on the widget.
      final visits = [_done(id: 1, day: _daysAgo(10))];
      final s = DashboardSummary.from(visits, now: _now);
      expect(s.today, 0);
      expect(s.todayTotal, 1);
    });

    test('leaderboards rank by count and truncate to topN', () {
      final visits = [
        for (var i = 0; i < 3; i++) _visit(id: i, partner: 'Acme'),
        for (var i = 3; i < 5; i++) _visit(id: i, partner: 'Globex'),
        _visit(id: 5, partner: 'Initech'),
        // No customer name — must not become an empty-string row.
        _visit(id: 6),
      ];
      final s = DashboardSummary.from(visits, now: _now, topN: 2);
      expect(s.topCustomers.map((e) => e.name), ['Acme', 'Globex']);
      expect(s.topCustomers.first.count, 3);
    });

    test('the employee board counts finished work only', () {
      // A draft is a commitment, not a delivery — crediting it would let
      // someone top the board by planning visits they never ran.
      final visits = [
        _done(id: 1, day: _now, employee: 'Sam'),
        _visit(id: 2, state: VisitState.approved, employee: 'Sam'),
        _visit(id: 3, state: VisitState.draft, employee: 'Mona'),
      ];
      final s = DashboardSummary.from(visits, now: _now);
      expect(s.topEmployees, hasLength(1));
      expect(s.topEmployees.single.name, 'Sam');
      expect(s.topEmployees.single.count, 1);
    });
  });

  group('WindowMetrics', () {
    test('an on-time rate over zero completed visits is 0, not NaN', () {
      final planned = [_visit(id: 1, state: VisitState.approved)];
      expect(WindowMetrics.from(planned).onTimePct, 0);
      expect(WindowMetrics.from(planned).avgMinutes, 0);
    });

    test('on-time is the share of completed visits run on their booked day',
        () {
      final visits = [
        _done(id: 1, day: _now),
        _done(id: 2, day: _now),
        // Ran three days after it was scheduled.
        _done(id: 3, day: _now, scheduleOffsetDays: 3),
        // Still open — excluded from the denominator entirely.
        _visit(id: 4, state: VisitState.approved, scheduled: _now),
      ];
      expect(WindowMetrics.from(visits).onTimePct, 67);
      // `count` is every visit in the window, completed or not.
      expect(WindowMetrics.from(visits).count, 4);
    });

    test('field km sums consecutive check-ins in time order', () {
      // Two points ~1.1km apart on a meridian (0.01° of latitude), fed in
      // reverse chronological order to prove the sort happens.
      final visits = [
        _done(id: 2, day: _now.add(const Duration(hours: 1)), lat: 30.01, lng: 31.0),
        _done(id: 1, day: _now, lat: 30.0, lng: 31.0),
      ];
      expect(WindowMetrics.from(visits).km, 1);
    });

    test('a visit with no GPS contributes no distance', () {
      final visits = [_done(id: 1, day: _now), _done(id: 2, day: _now)];
      expect(WindowMetrics.from(visits).km, 0);
    });
  });

  group('AnalyticsSummary', () {
    test('splits this week from last week', () {
      final visits = [
        _done(id: 1, day: _daysAgo(0)),
        _done(id: 2, day: _daysAgo(6)),
        // Day 7-13 is the previous window.
        _done(id: 3, day: _daysAgo(7)),
        _done(id: 4, day: _daysAgo(13)),
        // Older than both windows — counted in neither.
        _done(id: 5, day: _daysAgo(30)),
      ];
      final s = AnalyticsSummary.from(visits, now: _now);
      expect(s.current.count, 2);
      expect(s.previous.count, 2);
    });

    test('the weekly series has 7 buckets ending on today', () {
      final visits = [
        _done(id: 1, day: _daysAgo(0)),
        _done(id: 2, day: _daysAgo(0)),
        _done(id: 3, day: _daysAgo(6)),
      ];
      final s = AnalyticsSummary.from(visits, now: _now);
      expect(s.weeklyCounts, hasLength(7));
      expect(s.weeklyDays, hasLength(7));
      // Oldest first, today last.
      expect(s.weeklyCounts.first, 1);
      expect(s.weeklyCounts.last, 2);
      expect(s.weeklyMax, 2);
      expect(isSameDay(s.weeklyDays.last, _now), isTrue);
    });

    test('weeklyMax is 0 — not 1 — when there is nothing to plot', () {
      // The chart divides bar heights by this; a fake 1 would be harmless, but
      // callers also use it to decide whether to draw at all.
      expect(AnalyticsSummary.from(const [], now: _now).weeklyMax, 0);
    });

    test('a jump from a zero baseline reports +100%, not a division by zero',
        () {
      expect(AnalyticsSummary.pctDelta(5, 0), 100);
      expect(AnalyticsSummary.pctDelta(0, 0), 0);
      expect(AnalyticsSummary.pctDelta(15, 10), 50);
      expect(AnalyticsSummary.pctDelta(5, 10), -50);
    });

    test('the employee table ranks by on-time percentage, best first', () {
      final visits = [
        // Mona: 1 of 2 on time.
        _done(id: 1, day: _daysAgo(1), employee: 'Mona'),
        _done(id: 2, day: _daysAgo(2), employee: 'Mona', scheduleOffsetDays: 2),
        // Sam: 1 of 1 on time.
        _done(id: 3, day: _daysAgo(1), employee: 'Sam'),
      ];
      final rows = AnalyticsSummary.from(visits, now: _now).byEmployee;
      expect(rows.map((r) => r.name), ['Sam', 'Mona']);
      expect(rows.first.onTimePct, 100);
      expect(rows.last.onTimePct, 50);
      expect(rows.last.visits, 2);
    });

    test('employees are ranked on completed visits only', () {
      final visits = [
        _visit(id: 1, state: VisitState.approved, employee: 'Ghost'),
      ];
      expect(AnalyticsSummary.from(visits, now: _now).byEmployee, isEmpty);
    });
  });
}
