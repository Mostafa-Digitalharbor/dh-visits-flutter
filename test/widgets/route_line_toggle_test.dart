import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/map_matching/route_geometry.dart';
import 'package:location_gps/shared/widgets/route_line_toggle.dart';

import 'widget_harness.dart';

/// The toggle in the top-end corner of a map, where both trail maps put it.
Widget _onMap(
  Surface s, {
  RouteLineMode mode = RouteLineMode.roads,
  ValueChanged<RouteLineMode>? onChanged,
  bool pending = false,
  bool unmatched = false,
}) =>
    Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.mapBackground(s.brightness == Brightness.dark),
          ),
        ),
        PositionedDirectional(
          top: Insets.x3,
          end: Insets.x3,
          child: RouteLineToggle(
            key: const Key('toggle'),
            mode: mode,
            onChanged: onChanged ?? (_) {},
            pending: pending,
            unmatched: unmatched,
          ),
        ),
      ],
    );

/// The tappable segment carrying [label].
Finder _segment(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell));

/// The pill behind [label], which shows whether it is selected.
BoxDecoration _pill(WidgetTester tester, String label) => tester
    .widget<AnimatedContainer>(find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ))
    .decoration! as BoxDecoration;

final DateTime _t0 = DateTime.utc(2026, 9, 13, 12);

List<TracePoint> _trace(int n) => [
      for (var i = 0; i < n; i++)
        TracePoint(
          latitude: 24.7,
          longitude: 46.67 + i * 0.0005,
          time: _t0.add(Duration(seconds: 5 * i)),
        ),
    ];

RouteGeometry _matched(int n, {bool pending = false}) {
  final t = _trace(n);
  return RouteGeometry.fromRoads(
    [for (final p in t) p.latLng],
    [
      for (var i = 0; i < n - 1; i++)
        [t[i].latLng, LatLng(24.7001, t[i].longitude), t[i + 1].latLng],
    ],
    pending: pending,
  );
}

void main() {
  setUpAll(initHarness);

  group('RouteLineToggle layout', () {
    testOnEverySurface(
      'roads mode while matching fits over the map',
      (s) => _onMap(s, pending: true),
      verify: (tester, s) async {
        expect(find.text(l10n(s.locale).routeLineMatching), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testOnEverySurface(
      'roads mode with no road match fits and keeps the note narrow',
      (s) => _onMap(s, unmatched: true),
      verify: (tester, s) async {
        final note = find.text(l10n(s.locale).routeLineUnmatched);
        expect(note, findsOneWidget);
        final box = find.ancestor(of: note, matching: find.byType(Container));
        expect(tester.getSize(box.first).width, lessThanOrEqualTo(220));
        final text = tester.renderObject<RenderParagraph>(note);
        expect(text.maxLines, 2);
      },
    );

    testOnEverySurface('raw mode fits', (s) => _onMap(s, mode: RouteLineMode.raw));
  });

  group('RouteLineToggle behaviour', () {
    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('tapping the other segment switches, once — $surface',
          (tester) async {
        final t = l10n(surface.locale);
        final calls = <RouteLineMode>[];
        var mode = RouteLineMode.roads;
        await pumpSurface(
          tester,
          surface,
          StatefulBuilder(
            builder: (context, setState) => _onMap(
              surface,
              mode: mode,
              onChanged: (m) {
                calls.add(m);
                setState(() => mode = m);
              },
            ),
          ),
        );

        await tester.tap(find.text(t.routeLineGps));
        await tester.pump(const Duration(milliseconds: 200));
        expect(calls, [RouteLineMode.raw]);
        expect(_pill(tester, t.routeLineGps).color, AppColors.onMap);
        expect(_pill(tester, t.routeLineRoads).color, Colors.transparent);

        await tester.tap(find.text(t.routeLineRoads));
        await tester.pump(const Duration(milliseconds: 200));
        expect(calls, [RouteLineMode.raw, RouteLineMode.roads]);
        expect(_pill(tester, t.routeLineRoads).color, AppColors.onMap);
      });
    }

    for (final mode in RouteLineMode.values) {
      testWidgets('tapping the selected segment (${mode.name}) does nothing',
          (tester) async {
        final t = l10n(english);
        final calls = <RouteLineMode>[];
        await pumpSurface(
          tester,
          phoneEn,
          _onMap(phoneEn, mode: mode, onChanged: calls.add),
        );
        final selected =
            mode == RouteLineMode.roads ? t.routeLineRoads : t.routeLineGps;
        await tester.tap(find.text(selected));
        await tester.pump();
        expect(calls, isEmpty);
        expect(tester.widget<InkWell>(_segment(selected)).onTap, isNull);
      });
    }

    testWidgets('the selected segment is light on dark ink', (tester) async {
      final t = l10n(english);
      await pumpSurface(tester, phoneEn, _onMap(phoneEn));
      final roads = find.descendant(
        of: _segment(t.routeLineRoads),
        matching: find.byType(Icon),
      );
      final gps = find.descendant(
        of: _segment(t.routeLineGps),
        matching: find.byType(Icon),
      );
      expect(tester.widget<Icon>(roads).color, AppColors.ink);
      expect(tester.widget<Icon>(gps).color, AppColors.onMap);
      expect(
        tester.widget<Text>(find.text(t.routeLineRoads)).style?.color,
        AppColors.ink,
      );
      expect(
        tester.widget<Text>(find.text(t.routeLineGps)).style?.color,
        AppColors.onMap,
      );
      final track = tester.widget<Container>(find
          .descendant(
            of: find.byKey(const Key('toggle')),
            matching: find.byType(Container),
          )
          .first);
      expect((track.decoration! as BoxDecoration).color, AppColors.ink);
    });
  });

  group('RouteLineToggle matching note', () {
    Future<void> pumpState(
      WidgetTester tester, {
      required RouteLineMode mode,
      required bool pending,
      required bool unmatched,
      Surface surface = phoneEn,
    }) =>
        pumpSurface(
          tester,
          surface,
          _onMap(surface, mode: mode, pending: pending, unmatched: unmatched),
        );

    testWidgets('matching: a spinner and "matching…"', (tester) async {
      await pumpState(tester,
          mode: RouteLineMode.roads, pending: true, unmatched: false);
      expect(find.text(l10n(english).routeLineMatching), findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, AppColors.onMap);
      expect(tester.getSize(find.byType(CircularProgressIndicator)),
          const Size.square(10));
      // Indeterminate: keeps spinning; pump, never settle.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('matching wins over unmatched while it runs', (tester) async {
      await pumpState(tester,
          mode: RouteLineMode.roads, pending: true, unmatched: true);
      expect(find.text(l10n(english).routeLineMatching), findsOneWidget);
      expect(find.text(l10n(english).routeLineUnmatched), findsNothing);
    });

    testWidgets('unmatched: a plain note, no spinner', (tester) async {
      await pumpState(tester,
          mode: RouteLineMode.roads, pending: false, unmatched: true);
      expect(find.text(l10n(english).routeLineUnmatched), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<Text>(find.text(l10n(english).routeLineUnmatched))
            .style
            ?.color,
        AppColors.onMap,
      );
    });

    testWidgets('matched: no note at all', (tester) async {
      await pumpState(tester,
          mode: RouteLineMode.roads, pending: false, unmatched: false);
      expect(find.byType(Text), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    for (final (pending, unmatched) in const [
      (true, false),
      (false, true),
      (true, true),
    ]) {
      testWidgets(
          'raw mode never shows a note (pending $pending, unmatched $unmatched)',
          (tester) async {
        await pumpState(tester,
            mode: RouteLineMode.raw, pending: pending, unmatched: unmatched);
        expect(find.byType(Text), findsNWidgets(2));
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    }

    testWidgets('the note is Arabic in ar', (tester) async {
      await pumpState(tester,
          surface: phoneAr,
          mode: RouteLineMode.roads,
          pending: false,
          unmatched: true);
      expect(find.text(l10n(arabic).routeLineUnmatched), findsOneWidget);
      expect(find.text(l10n(arabic).routeLineRoads), findsOneWidget);
      expect(find.text(l10n(arabic).routeLineGps), findsOneWidget);
    });
  });

  group('RouteLineToggle direction', () {
    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('segments follow reading order; the note hugs the end — '
          '$surface', (tester) async {
        final t = l10n(surface.locale);
        await pumpSurface(tester, surface, _onMap(surface, pending: true));
        final roads = tester.getCenter(find.text(t.routeLineRoads)).dx;
        final gps = tester.getCenter(find.text(t.routeLineGps)).dx;
        final toggle = tester.getRect(find.byKey(const Key('toggle')));
        final spinner = tester.getCenter(find.byType(CircularProgressIndicator));
        final note = tester.getCenter(find.text(t.routeLineMatching));
        if (surface.isArabic) {
          expect(roads, greaterThan(gps));
          expect(toggle.left, moreOrLessEquals(Insets.x3));
          expect(spinner.dx, greaterThan(note.dx));
        } else {
          expect(roads, lessThan(gps));
          expect(toggle.right, moreOrLessEquals(390 - Insets.x3));
          expect(spinner.dx, lessThan(note.dx));
        }
        // Both the track and the note end on the same edge.
        final track = tester.getRect(find
            .descendant(
              of: find.byKey(const Key('toggle')),
              matching: find.byType(Container),
            )
            .first);
        final noteBox = tester.getRect(find
            .ancestor(
              of: find.text(t.routeLineMatching),
              matching: find.byType(Container),
            )
            .first);
        if (surface.isArabic) {
          expect(noteBox.left, moreOrLessEquals(track.left));
        } else {
          expect(noteBox.right, moreOrLessEquals(track.right));
        }
      });
    }
  });

  group('RouteLineToggle accessibility', () {
    testWidgets('segments are labelled buttons that report selection',
        (tester) async {
      final handle = tester.ensureSemantics();
      final t = l10n(english);
      await pumpSurface(tester, phoneEn, _onMap(phoneEn));
      expect(
        tester.getSemantics(_segment(t.routeLineRoads)),
        containsSemantics(
          label: t.routeLineRoads,
          isButton: true,
          isSelected: true,
          hasTapAction: false,
        ),
      );
      expect(
        tester.getSemantics(_segment(t.routeLineGps)),
        containsSemantics(
          label: t.routeLineGps,
          isButton: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      // The label is read once, not again from the inner Text.
      expect(find.bySemanticsLabel(t.routeLineGps), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a screen reader can switch the line (tap action)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final t = l10n(arabic);
      final calls = <RouteLineMode>[];
      await pumpSurface(tester, phoneAr, _onMap(phoneAr, onChanged: calls.add));
      tester.semantics.tap(find.semantics.byLabel(t.routeLineGps));
      await tester.pump();
      expect(calls, [RouteLineMode.raw]);
      handle.dispose();
    });

    // A compact map overlay: the segments are below the 48dp guideline (see
    // the report), but must not drop below WCAG 2.2's 24dp minimum target.
    for (final surface in surfaces) {
      testWidgets('each segment is at least 24dp tall — $surface',
          (tester) async {
        final t = l10n(surface.locale);
        await pumpSurface(tester, surface, _onMap(surface));
        for (final label in [t.routeLineRoads, t.routeLineGps]) {
          final size = tester.getSize(_segment(label));
          expect(size.height, greaterThanOrEqualTo(24));
          expect(size.width, greaterThanOrEqualTo(24));
        }
      });
    }
  });

  group('RouteLineToggle.stateOf', () {
    test('nothing drawn: neither pending nor unmatched', () {
      expect(RouteLineToggle.stateOf(const []),
          (pending: false, unmatched: false));
      // A single fix draws no line and doesn't count.
      expect(
        RouteLineToggle.stateOf([RouteGeometry.raw(_trace(1), pending: true)]),
        (pending: false, unmatched: false),
      );
    });

    test('any drawn geometry still matching makes the map pending', () {
      expect(
        RouteLineToggle.stateOf([
          _matched(4),
          RouteGeometry.raw(_trace(3), pending: true),
        ]),
        (pending: true, unmatched: false),
      );
    });

    test('finished and all raw: unmatched', () {
      expect(
        RouteLineToggle.stateOf([
          RouteGeometry.raw(_trace(3)),
          RouteGeometry.raw(_trace(5)),
          RouteGeometry.raw(_trace(1)),
        ]),
        (pending: false, unmatched: true),
      );
    });

    test('one matched or partial geometry is enough to not be unmatched', () {
      expect(
        RouteLineToggle.stateOf([RouteGeometry.raw(_trace(3)), _matched(3)]),
        (pending: false, unmatched: false),
      );
      final t = _trace(3);
      final partial = RouteGeometry.fromRoads(
        [for (final p in t) p.latLng],
        [
          [t[0].latLng, LatLng(24.7001, t[0].longitude), t[1].latLng],
          null,
        ],
      );
      expect(partial.source, RouteGeometrySource.partial);
      expect(
        RouteLineToggle.stateOf([partial]),
        (pending: false, unmatched: false),
      );
    });

    test('a pending all-raw geometry is pending, not unmatched', () {
      expect(
        RouteLineToggle.stateOf([RouteGeometry.raw(_trace(4), pending: true)]),
        (pending: true, unmatched: false),
      );
    });
  });
}
