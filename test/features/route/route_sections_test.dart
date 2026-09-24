import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/features/route/bloc/day_trails_cubit.dart';
import 'package:location_gps/features/route/view/route_map.dart';
import 'package:location_gps/features/route/view/route_sections.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

const _lead = Key('lead');

DayTrail _trail(
  int id, {
  String? partner = LongText.arabicCompany,
  String? name = 'VIS/2026/00042',
  bool ended = true,
  int fixes = 12,
  double km = 3.456,
}) =>
    DayTrail(
      visit: Visit(
        id: id,
        name: name,
        partnerName: partner,
        startDatetime: fixtureDay,
        endDatetime: ended ? fixtureDay.add(const Duration(hours: 1)) : null,
      ),
      track: VisitTrack(
        visitId: id,
        locationLogCount: fixes,
        trackedDistanceKm: km,
        logs: trailLogs(2),
      ),
    );

Visit _stop(int id, {DateTime? at, String? partner = LongText.arabicCompany}) =>
    Visit(id: id, name: 'VIS/$id', partnerName: partner, scheduledDatetime: at);

String _time(WidgetTester tester, DateTime utc) {
  final context = tester.element(find.byType(Scaffold).first);
  return AppDate.timeFormat(context).format(utc.toLocal());
}

void main() {
  setUpAll(initHarness);

  group('RouteNotice', () {
    testOnEverySurface(
      'a long failure with its retry fits',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: RouteNotice(
          message: '${l10n(s.locale).routeTrailsLoadFailed(12)} '
              '${LongText.of(s)}',
          onRetry: () {},
        ),
      ),
      verify: (tester, s) async {
        expect(find.text(l10n(s.locale).commonRetry), findsOneWidget);
        final message = tester.widget<Text>(find.textContaining(
            l10n(s.locale).routeTrailsLoadFailed(12)));
        expect(message.maxLines, isNull, reason: 'the reason wraps in full');
      },
    );

    testWidgets('retry fires once and is a full tap target', (tester) async {
      var retries = 0;
      await pumpSurface(
        tester,
        phoneAr,
        RouteNotice(message: 'x', onRetry: () => retries++),
      );
      final retry = find.widgetWithText(TextButton, l10n(arabic).commonRetry);
      expect(tester.getSize(retry).height,
          greaterThanOrEqualTo(kMinInteractiveDimension));
      await tester.tap(retry);
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('a short reason keeps retry beside it, at the end',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(
            tester, s, RouteNotice(message: 'Failed', onRetry: () {}));
        final message = tester.getRect(find.text('Failed'));
        final retry = tester.getRect(find.byType(TextButton));
        expect(retry.top, lessThan(message.bottom), reason: s.name);
        expect(retry.center.dx > message.center.dx, s == phoneEn,
            reason: s.name);
      }
    });

    testWidgets('a long reason drops retry beneath it', (tester) async {
      final long = LongText.arabicCompany * 3;
      await pumpSurface(
        tester,
        surfaces[0],
        RouteNotice(message: long, onRetry: () {}),
      );
      final message = tester.getRect(find.text(long));
      final retry = tester.getRect(find.byType(TextButton));
      expect(retry.top, greaterThanOrEqualTo(message.bottom));
      // Under the text, from its start edge (the right, in Arabic).
      expect(retry.right, moreOrLessEquals(message.right, epsilon: 1));
      expectCleanLayout(tester);
    });

    testWidgets('without a retry there is no button', (tester) async {
      await pumpSurface(tester, phoneEn, const RouteNotice(message: 'Failed'));
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('is drawn in the error tones', (tester) async {
      await pumpSurface(tester, phoneEn, const RouteNotice(message: 'Failed'));
      final cs = Theme.of(tester.element(find.byType(RouteNotice))).colorScheme;
      expect(tester.widget<Icon>(find.byIcon(Symbols.error)).color, cs.error);
      expect(tester.widget<Text>(find.text('Failed')).style?.color,
          cs.onErrorContainer);
      final box = tester.widget<Container>(find
          .descendant(
              of: find.byType(RouteNotice), matching: find.byType(Container))
          .first);
      expect((box.decoration! as BoxDecoration).color,
          cs.errorContainer.withValues(alpha: Alphas.soft));
    });

    testWidgets('an empty message still lays out', (tester) async {
      await pumpSurface(
          tester, phoneEn, RouteNotice(message: '', onRetry: () {}));
      expectCleanLayout(tester);
    });
  });

  group('RouteVisitRow', () {
    Widget row(Surface s, {VoidCallback? onTap}) => RouteVisitRow(
          leading: const SizedBox(key: _lead, width: 6, height: 40),
          title: LongText.of(s),
          subtitle: '${LongText.of(s)} ${LongText.arabicPerson}',
          summary: '1,234 ${l10n(s.locale).routePointsCount(1234)}',
          onTap: onTap ?? () {},
        );

    testOnEverySurface(
      'long title, subtitle and summary share one row',
      (s) => Padding(padding: const EdgeInsets.all(16), child: row(s)),
      verify: (tester, s) async {
        for (final text in tester.widgetList<Text>(find.descendant(
            of: find.byType(RouteVisitRow), matching: find.byType(Text)))) {
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
        }
        expect(tester.getSize(find.byType(RouteVisitRow)).height,
            greaterThanOrEqualTo(kMinInteractiveDimension));
      },
    );

    testWidgets('a tap anywhere fires once', (tester) async {
      var taps = 0;
      await pumpSurface(tester, phoneEn, row(phoneEn, onTap: () => taps++));
      await tester.tap(find.byType(RouteVisitRow));
      await tester.pump();
      await tester.tap(find.text(LongText.english).first);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('the leading mark sits at the start in both languages',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, row(s));
        final lead = tester.getCenter(find.byKey(_lead)).dx;
        final chevron =
            tester.getCenter(find.byIcon(Symbols.chevron_right)).dx;
        expect(lead < chevron, s == phoneEn, reason: s.name);
        final icon = tester.widget<Icon>(find.byIcon(Symbols.chevron_right));
        expect(icon.icon!.matchTextDirection, isTrue,
            reason: 'the chevron mirrors itself');
      }
    });

    testWidgets('empty strings still lay out', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        RouteVisitRow(
          leading: const SizedBox(),
          title: '',
          subtitle: '',
          summary: '',
          onTap: () {},
        ),
      );
      expectCleanLayout(tester);
    });
  });

  group('RecordedTrailsSection', () {
    testOnEverySurface(
      'three long trails and a failure notice fit',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: RecordedTrailsSection(
          trails: [
            _trail(1, fixes: 123456, km: 12345.678),
            _trail(2, ended: false),
            _trail(3, partner: null, name: null),
          ],
          failed: 7,
          onRetry: () {},
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.routeRecordedTrails), findsOneWidget);
        expect(find.byType(RouteVisitRow), findsNWidgets(3));
        expect(find.text(t.routeTrailsLoadFailed(7)), findsOneWidget);
      },
    );

    testWidgets('nothing recorded and nothing failed: no title, no rows',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        RecordedTrailsSection(trails: const [], failed: 0, onRetry: () {}),
      );
      expect(find.text(l10n(english).routeRecordedTrails), findsNothing);
      expect(find.byType(RouteVisitRow), findsNothing);
      expect(find.byType(RouteNotice), findsNothing);
    });

    testWidgets('only failures: the notice alone, and retry fires once',
        (tester) async {
      var retries = 0;
      await pumpSurface(
        tester,
        phoneAr,
        RecordedTrailsSection(
            trails: const [], failed: 2, onRetry: () => retries++),
      );
      final t = l10n(arabic);
      expect(find.text(t.routeRecordedTrails), findsNothing);
      expect(find.text(t.routeTrailsLoadFailed(2)), findsOneWidget);
      await tester.tap(find.text(t.commonRetry));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('each row: title, reference and times, points and distance',
        (tester) async {
      final trail = _trail(1, fixes: 1234, km: 3.456);
      await pumpSurface(
        tester,
        phoneEn,
        RecordedTrailsSection(trails: [trail], failed: 0, onRetry: () {}),
      );
      final t = l10n(english);
      final row = tester.widget<RouteVisitRow>(find.byType(RouteVisitRow));
      expect(row.title, LongText.arabicCompany);
      final range = t.commonTimeRange(
        _time(tester, trail.visit.startDatetime!),
        _time(tester, trail.visit.endDatetime!),
      );
      expect(row.subtitle, 'VIS/2026/00042${t.commonListSeparator}$range');
      expect(
        row.summary,
        '${t.routePointsCount(1234)}${t.commonListSeparator}'
        '${AppNumber.km(t, 3.456, precise: true)}',
      );
    });

    testWidgets('a running visit shows "no value" for its end',
        (tester) async {
      final trail = _trail(1, ended: false, name: null);
      await pumpSurface(
        tester,
        phoneEn,
        RecordedTrailsSection(trails: [trail], failed: 0, onRetry: () {}),
      );
      final t = l10n(english);
      final row = tester.widget<RouteVisitRow>(find.byType(RouteVisitRow));
      expect(
        row.subtitle,
        t.commonTimeRange(
            _time(tester, trail.visit.startDatetime!), t.commonNoValue),
      );
    });

    testWidgets('without a customer the title falls back to the reference',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        RecordedTrailsSection(
          trails: [
            _trail(1, partner: null),
            _trail(2, partner: null, name: null),
          ],
          failed: 0,
          onRetry: () {},
        ),
      );
      final titles = tester
          .widgetList<RouteVisitRow>(find.byType(RouteVisitRow))
          .map((r) => r.title)
          .toList();
      expect(titles, ['VIS/2026/00042', l10n(arabic).visitFallbackTitle(2)]);
    });

    testWidgets('the colour bars key rows to their map lines', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        RecordedTrailsSection(
          trails: [for (var i = 0; i < 4; i++) _trail(i)],
          failed: 0,
          onRetry: () {},
        ),
        scrollable: true,
      );
      final bars = tester
          .widgetList<RouteVisitRow>(find.byType(RouteVisitRow))
          .map((r) =>
              ((r.leading as Container).decoration! as BoxDecoration).color)
          .toList();
      expect(bars, [for (var i = 0; i < 4; i++) AppColors.routePaletteAt(i)]);
    });

    testWidgets('a row opens that visit\'s full trail', (tester) async {
      final trails = [_trail(5), _trail(6)];
      final log = await pumpRouted(
        tester,
        phoneEn,
        RecordedTrailsSection(trails: trails, failed: 0, onRetry: () {}),
      );
      await tester.tap(find.byType(RouteVisitRow).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log.locations, ['/visits/6/trail']);
      expect(log.extras.single, trails[1].visit);
    });
  });

  group('RouteStopRow', () {
    Widget stop(
      Surface s, {
      int index = 1,
      Visit? visit,
      bool isNext = false,
      bool isLast = false,
      int? drive = 25,
    }) =>
        RouteStopRow(
          index: index,
          visit: visit ?? _stop(7, at: fixtureDay),
          isNext: isNext,
          isLast: isLast,
          driveMinutes: drive,
        );

    testOnEverySurface(
      'the densest stop: first, next, long name, a long drive',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            stop(s, index: 0, isNext: true, drive: 12345),
            stop(s, index: 998, isLast: true, drive: null),
          ],
        ),
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(t.routeNextStop), findsOneWidget);
        expect(find.text(t.routeDriveMinutes(12345)), findsOneWidget);
        expect(find.text('999'), findsOneWidget);
      },
    );

    testWidgets('the first stop is labelled the start point', (tester) async {
      await pumpSurface(tester, phoneEn, stop(phoneEn, index: 0));
      final t = l10n(english);
      final eta = _time(tester, fixtureDay);
      expect(find.text('$eta${t.commonListSeparator}${t.routeStartPoint}'),
          findsOneWidget);
    });

    testWidgets('later stops show only the time, in the user zone',
        (tester) async {
      await pumpSurface(tester, phoneAr, stop(phoneAr, index: 3));
      expect(find.text(_time(tester, fixtureDay)), findsOneWidget);
      expect(find.textContaining(l10n(arabic).routeStartPoint), findsNothing);
      expect(find.text('4'), findsOneWidget, reason: 'numbered from one');
    });

    testWidgets('no planned time reads "no value"', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        stop(phoneEn, visit: _stop(7)),
      );
      expect(find.text(l10n(english).commonNoValue), findsOneWidget);
    });

    testWidgets('the drive is shown only when known', (tester) async {
      await pumpSurface(tester, phoneEn, stop(phoneEn, drive: 0));
      expect(find.text(l10n(english).routeDriveMinutes(0)), findsOneWidget);
      expect(find.byIcon(Symbols.directions_car), findsOneWidget);

      await pumpSurface(tester, phoneEn, stop(phoneEn, drive: null));
      expect(find.byIcon(Symbols.directions_car), findsNothing);
    });

    testWidgets('the next stop glows and says so', (tester) async {
      await pumpSurface(tester, phoneEn, stop(phoneEn, isNext: true));
      final pin = tester.widget<StopNumberPin>(find.byType(StopNumberPin));
      expect(pin.isNext, isTrue);
      final context = tester.element(find.byType(RouteStopRow));
      final glow = tester.widget<DecoratedBox>(find
          .ancestor(
              of: find.byType(StopNumberPin),
              matching: find.byType(DecoratedBox))
          .first);
      expect((glow.decoration as BoxDecoration).boxShadow, context.x.glowBrand);
      final pill = tester.widget<TonePill>(find.byType(TonePill));
      expect(pill.label, l10n(english).routeNextStop);
      expect(pill.color, Theme.of(context).colorScheme.primary);
    });

    testWidgets('other stops neither glow nor say "next"', (tester) async {
      await pumpSurface(tester, phoneEn, stop(phoneEn));
      expect(find.byType(TonePill), findsNothing);
      final glow = tester.widget<DecoratedBox>(find
          .ancestor(
              of: find.byType(StopNumberPin),
              matching: find.byType(DecoratedBox))
          .first);
      expect((glow.decoration as BoxDecoration).boxShadow, isNull);
    });

    testWidgets('a connector joins every stop but the last', (tester) async {
      Finder connector() => find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxWidth == 2 &&
          w.color != null);
      await pumpSurface(tester, phoneEn, stop(phoneEn));
      expect(connector(), findsOneWidget);
      final context = tester.element(find.byType(RouteStopRow));
      expect(tester.widget<Container>(connector()).color, context.x.divider);

      await pumpSurface(tester, phoneEn, stop(phoneEn, isLast: true));
      expect(connector(), findsNothing);
    });

    testWidgets('the number sits at the start in both languages',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, stop(s));
        final pin = tester.getCenter(find.byType(StopNumberPin)).dx;
        final title = tester.getCenter(find.text(LongText.arabicCompany)).dx;
        expect(pin < title, s == phoneEn, reason: s.name);
      }
    });

    testWidgets('tapping a stop opens the visit, once', (tester) async {
      final visit = _stop(31, at: fixtureDay);
      final log = await pumpRouted(
        tester,
        phoneEn,
        RouteStopRow(
          index: 0,
          visit: visit,
          isNext: false,
          isLast: false,
          driveMinutes: null,
        ),
      );
      await tester.tap(find.text(LongText.arabicCompany));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(log.locations, ['/visits/31']);
      expect(log.extras.single, visit);
    });

    testWidgets('without a customer the title is the reference',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        stop(phoneEn, visit: _stop(7, at: fixtureDay, partner: null)),
      );
      final title = tester.widget<Text>(find.text('VIS/7'));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });
}
