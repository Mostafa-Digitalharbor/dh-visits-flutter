import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/design/app_decor.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/features/analytics/view/metric_tile.dart';
import 'package:location_gps/shared/widgets/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/widget_harness.dart';

const _start = Key('start');
const _end = Key('end');

/// The delta chip is private; its arrow is the one [Icon] at the pill size
/// (the badge's glyph is responsive and larger).
Icon _deltaArrow(WidgetTester tester, Finder tile) => tester
    .widgetList<Icon>(find.descendant(of: tile, matching: find.byType(Icon)))
    .singleWhere((i) => i.size == IconSz.pill);

Text _textWith(WidgetTester tester, String value) =>
    tester.widget<Text>(find.text(value));

void main() {
  setUpAll(initHarness);

  group('MetricDelta', () {
    test('reads its sign, and higherIsBetter flips the verdict', () {
      const up = MetricDelta(change: 5, text: '+5%');
      const down = MetricDelta(change: -3, text: '−3');
      const flat = MetricDelta(change: 0, text: '0');
      const shorter =
          MetricDelta(change: -2, text: '−2 min', higherIsBetter: false);
      const longer =
          MetricDelta(change: 2, text: '+2 min', higherIsBetter: false);

      expect((up.isUp, up.isFlat, up.isGood), (true, false, true));
      expect((down.isUp, down.isFlat, down.isGood), (false, false, false));
      expect((flat.isUp, flat.isFlat, flat.isGood), (false, true, false));
      expect(shorter.isGood, isTrue);
      expect(longer.isGood, isFalse);
      // Fractions are signs too.
      expect(const MetricDelta(change: 0.01, text: '+0').isUp, isTrue);
    });
  });

  group('MetricTile layout', () {
    testOnEverySurface(
      'two tiles side by side with huge values, long labels and 3-digit deltas',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: MetricTileRow(
          start: MetricTile(
            key: _start,
            icon: Symbols.route,
            tone: Colors.teal,
            value: '1,234,567.89 km',
            label: LongText.of(s),
            delta: const MetricDelta(change: 100, text: '+100%'),
          ),
          end: MetricTile(
            key: _end,
            icon: Symbols.timer,
            tone: Colors.orange,
            value: '999,999',
            label: LongText.of(s),
            countUp: true,
            delta: const MetricDelta(
              change: -125,
              text: '−125 min',
              higherIsBetter: false,
            ),
          ),
        ),
      ),
      verify: (tester, s) async {
        // Finish the count-up so the final (widest) figure is laid out too.
        await tester.pump(AppDurations.countUp);
        await tester.pump();
        final start = tester.getSize(find.byKey(_start));
        final end = tester.getSize(find.byKey(_end));
        expect(start.width, moreOrLessEquals(end.width),
            reason: 'the row shares the width evenly');
        // The value scales down on one line instead of wrapping.
        expect(_textWith(tester, '1,234,567.89 km').maxLines, 1);
        final fitted = find.ancestor(
          of: find.text('1,234,567.89 km'),
          matching: find.byType(FittedBox),
        );
        expect(tester.widget<FittedBox>(fitted.first).fit, BoxFit.scaleDown);
        // The caption is one ellipsized line.
        final labels = tester.widgetList<Text>(find.text(LongText.of(s)));
        expect(labels, hasLength(2));
        for (final label in labels) {
          expect(label.maxLines, 1);
          expect(label.overflow, TextOverflow.ellipsis);
        }
      },
    );

    testOnEverySurface(
      'a lone tile without a delta, with an empty label and a zero',
      (s) => const Padding(
        padding: EdgeInsets.all(16),
        child: MetricTile(
          icon: Symbols.check,
          tone: Colors.green,
          value: '0',
          label: '',
        ),
      ),
      verify: (tester, _) async {
        expect(find.byType(Spacer), findsNothing,
            reason: 'no delta, nothing to push to the end');
        expect(find.text('0'), findsOneWidget);
      },
    );

    testOnEverySurface(
      'a very long single-word value in a quarter-width tile',
      (s) => Row(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: MetricTile(
              icon: Symbols.speed,
              tone: Colors.blue,
              value: '12345678901234567890',
              label: 'x' * 80,
              delta: const MetricDelta(change: 0, text: '±0%'),
            ),
          ),
          const Expanded(child: SizedBox()),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  });

  group('MetricTile behaviour', () {
    Future<Finder> pumpTile(
      WidgetTester tester,
      MetricDelta delta, {
      Surface surface = phoneEn,
    }) async {
      await pumpSurface(
        tester,
        surface,
        MetricTile(
          key: _start,
          icon: Symbols.route,
          tone: Colors.teal,
          value: '12',
          label: 'Visits',
          delta: delta,
        ),
      );
      return find.byKey(_start);
    }

    testWidgets('a good rise is green with an up arrow', (tester) async {
      final tile =
          await pumpTile(tester, const MetricDelta(change: 5, text: '+5%'));
      final arrow = _deltaArrow(tester, tile);
      final x = tester.element(tile).x;
      expect(arrow.icon, Symbols.trending_up);
      expect(arrow.color, x.success);
      expect(_textWith(tester, '+5%').style?.color, x.success);
    });

    testWidgets('a bad fall is the error colour with a down arrow',
        (tester) async {
      final tile =
          await pumpTile(tester, const MetricDelta(change: -5, text: '−5%'));
      final arrow = _deltaArrow(tester, tile);
      final context = tester.element(tile);
      expect(arrow.icon, Symbols.trending_down);
      expect(arrow.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('a fall that is good news is green but still points down',
        (tester) async {
      final tile = await pumpTile(
        tester,
        const MetricDelta(change: -3, text: '−3 min', higherIsBetter: false),
      );
      final arrow = _deltaArrow(tester, tile);
      expect(arrow.icon, Symbols.trending_down);
      expect(arrow.color, tester.element(tile).x.success);
    });

    testWidgets('no change is neutral with a flat arrow', (tester) async {
      final tile =
          await pumpTile(tester, const MetricDelta(change: 0, text: '0%'));
      final arrow = _deltaArrow(tester, tile);
      expect(arrow.icon, Symbols.trending_flat);
      expect(arrow.color, tester.element(tile).x.textTertiary);
    });

    testWidgets('the delta keeps its sign on the left in Arabic',
        (tester) async {
      await pumpTile(
        tester,
        const MetricDelta(change: 5, text: '+5%'),
        surface: phoneAr,
      );
      expect(_textWith(tester, '+5%').textDirection, TextDirection.ltr);
    });

    testWidgets('the badge is tinted with the tone and the panel is themed',
        (tester) async {
      final tile =
          await pumpTile(tester, const MetricDelta(change: 1, text: '+1'));
      final badge = tester.widget<IconBadge>(
          find.descendant(of: tile, matching: find.byType(IconBadge)));
      expect(badge.color, Colors.teal);
      expect(badge.icon, Symbols.route);

      final context = tester.element(tile);
      final panel = tester.widget<Container>(find
          .descendant(of: tile, matching: find.byType(Container))
          .first);
      final expected = AppDecor.panel(context);
      final actual = panel.decoration! as BoxDecoration;
      expect(actual.color, expected.color);
      expect(actual.border, expected.border);
      expect(_textWith(tester, '12').style?.color,
          Theme.of(context).colorScheme.onSurface);
      expect(_textWith(tester, 'Visits').style?.color,
          context.x.textTertiary);
    });

    testWidgets('countUp animates a whole number up from zero',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const MetricTile(
          icon: Symbols.route,
          tone: Colors.teal,
          value: '27',
          label: 'Visits',
          countUp: true,
        ),
        settle: Duration.zero,
      );
      expect(find.byType(CountUpText), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pump(AppDurations.countUp ~/ 2);
      final mid = tester
          .widget<Text>(find.descendant(
              of: find.byType(CountUpText), matching: find.byType(Text)))
          .data!;
      expect(int.parse(mid), inExclusiveRange(0, 27));
      await tester.pump(AppDurations.countUp);
      expect(find.text('27'), findsOneWidget);
    });

    testWidgets('countUp shows a value it cannot count as it is',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const MetricTile(
          icon: Symbols.timer,
          tone: Colors.teal,
          value: '00:58',
          label: 'Average',
          countUp: true,
        ),
        settle: Duration.zero,
      );
      expect(find.text('00:58'), findsOneWidget);
    });

    testWidgets('without countUp the value is a plain one-line text',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const MetricTile(
          icon: Symbols.timer,
          tone: Colors.teal,
          value: '27',
          label: 'Visits',
        ),
        settle: Duration.zero,
      );
      expect(find.byType(CountUpText), findsNothing);
      expect(find.text('27'), findsOneWidget);
    });
  });

  group('MetricTileRow', () {
    Future<(Offset, Offset)> positions(WidgetTester tester, Surface s) async {
      await pumpSurface(
        tester,
        s,
        const MetricTileRow(
          start: SizedBox(key: _start, height: 40),
          end: SizedBox(key: _end, height: 40),
        ),
      );
      return (
        tester.getTopLeft(find.byKey(_start)),
        tester.getTopLeft(find.byKey(_end)),
      );
    }

    testWidgets('start leads in English', (tester) async {
      final (start, end) = await positions(tester, phoneEn);
      expect(start.dx, lessThan(end.dx));
    });

    testWidgets('start leads from the right in Arabic', (tester) async {
      final (start, end) = await positions(tester, phoneAr);
      expect(start.dx, greaterThan(end.dx));
    });

    testWidgets('the two halves are equal with a gap between them',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const MetricTileRow(
          start: SizedBox(key: _start, height: 40),
          end: SizedBox(key: _end, height: 40),
        ),
      );
      final a = tester.getRect(find.byKey(_start));
      final b = tester.getRect(find.byKey(_end));
      expect(a.width, b.width);
      expect(b.left - a.right, greaterThan(0));
      expect(a.width * 2 + (b.left - a.right), phoneEn.size.width);
    });
  });
}
