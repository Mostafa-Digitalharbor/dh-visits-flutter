import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/animated_list_item.dart';

import 'widget_harness.dart';

const _frame = Duration(milliseconds: 16);

/// Pumps [total] as ~60Hz frames. A controller's clock starts on the first
/// frame after it is started, so one big `pump` would hide the stagger.
Future<void> _frames(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(_frame);
    elapsed += _frame;
  }
}

Finder _row(int i) => find.byKey(ValueKey('row-$i'));

Finder _in(Finder item, Type type) =>
    find.descendant(of: item, matching: find.byType(type));

double _opacity(WidgetTester tester, Finder item) =>
    tester.widget<FadeTransition>(_in(item, FadeTransition)).opacity.value;

Offset _slide(WidgetTester tester, Finder item) =>
    tester.widget<SlideTransition>(_in(item, SlideTransition)).position.value;

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(_in(find.byType(ScaleFadeIn), ScaleTransition))
    .scale
    .value;

double _fade(WidgetTester tester) => tester
    .widget<FadeTransition>(_in(find.byType(ScaleFadeIn), FadeTransition))
    .opacity
    .value;

Widget _rows(
  int count, {
  Duration step = const Duration(milliseconds: 55),
  Duration duration = const Duration(milliseconds: 380),
  Duration maxDelay = const Duration(milliseconds: 350),
  int animateBelowIndex = 12,
}) => Column(
  children: [
    for (var i = 0; i < count; i++)
      AnimatedListItem(
        key: ValueKey('row-$i'),
        index: i,
        step: step,
        duration: duration,
        maxDelay: maxDelay,
        animateBelowIndex: animateBelowIndex,
        child: SizedBox(height: 20, child: Text('row $i')),
      ),
  ],
);

void main() {
  setUpAll(initHarness);

  group('AnimatedListItem layout', () {
    testOnEverySurface(
      'a long list of rows with long text cascades in without overflow',
      (s) => ListView.builder(
        itemCount: 30,
        itemBuilder: (context, i) => AnimatedListItem(
          key: ValueKey('row-$i'),
          index: i,
          child: ListTile(
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: Text('${LongText.of(s)} #$i'),
            subtitle: Text(LongText.arabicPerson),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
      verify: (tester, s) async {
        // 350ms max stagger + 380ms animation, well past the harness settle.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        for (var i = 0; i < 12; i++) {
          final row = _row(i);
          if (row.evaluate().isEmpty) break; // not built on this viewport
          expect(_opacity(tester, row), 1, reason: 'row $i');
          expect(_slide(tester, row), Offset.zero, reason: 'row $i');
        }
      },
    );

    testOnEverySurface(
      'ScaleFadeIn around an empty-state block lands at full size',
      (s) => ScaleFadeIn(
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 96),
            Text(LongText.of(s), textAlign: TextAlign.center),
            Text(l10n(s.locale).customersEmpty),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        await tester.pumpAndSettle();
        expect(_fade(tester), 1);
        expect(_scale(tester), 1);
        expect(find.text(l10n(s.locale).customersEmpty), findsOneWidget);
      },
    );
  });

  group('AnimatedListItem behaviour', () {
    testWidgets('the first row starts transparent and lowered, then settles', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _rows(1), settle: Duration.zero);
      expect(_opacity(tester, _row(0)), 0);
      expect(_slide(tester, _row(0)), const Offset(0, 0.08));

      await _frames(tester, const Duration(milliseconds: 190));
      final midFade = _opacity(tester, _row(0));
      final midSlide = _slide(tester, _row(0)).dy;
      expect(midFade, inExclusiveRange(0, 1));
      expect(midSlide, inExclusiveRange(0, 0.08));

      await _frames(tester, const Duration(milliseconds: 200));
      expect(_opacity(tester, _row(0)), 1);
      expect(_slide(tester, _row(0)), Offset.zero);
    });

    testWidgets('slides up in place: vertical only, whatever the direction', (
      tester,
    ) async {
      Future<(Offset, Offset)> positions(Surface s) async {
        await pumpSurface(tester, s, _rows(1), settle: Duration.zero);
        await _frames(tester, const Duration(milliseconds: 64));
        final mid = tester.getTopLeft(find.text('row 0'));
        await tester.pumpAndSettle();
        final end = tester.getTopLeft(find.text('row 0'));
        await tester.pumpWidget(const SizedBox.shrink());
        return (mid, end);
      }

      for (final s in [phoneEn, phoneAr]) {
        final (mid, end) = await positions(s);
        expect(mid.dx, end.dx, reason: '$s: slid sideways');
        expect(mid.dy, greaterThan(end.dy), reason: '$s: did not rise');
      }
    });

    testWidgets('rows stagger by index × step', (tester) async {
      await pumpSurface(tester, phoneEn, _rows(4), settle: Duration.zero);

      // 100ms in: rows 0 (0ms) and 1 (55ms) are moving, 2 (110ms) and
      // 3 (165ms) have not started.
      await _frames(tester, const Duration(milliseconds: 100));
      expect(_opacity(tester, _row(0)), greaterThan(0));
      expect(_opacity(tester, _row(1)), greaterThan(0));
      expect(_opacity(tester, _row(2)), 0);
      expect(_opacity(tester, _row(3)), 0);

      // 200ms in: all four are moving, each behind the one above it.
      await _frames(tester, const Duration(milliseconds: 100));
      final o = [for (var i = 0; i < 4; i++) _opacity(tester, _row(i))];
      expect(o[3], greaterThan(0));
      expect(o[0], greaterThan(o[1]));
      expect(o[1], greaterThan(o[2]));
      expect(o[2], greaterThan(o[3]));

      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        expect(_opacity(tester, _row(i)), 1);
      }
    });

    testWidgets('the stagger is clamped to maxDelay', (tester) async {
      await pumpSurface(tester, phoneEn, _rows(12), settle: Duration.zero);
      // Row 6 waits 330ms; rows 7 (385ms) and 11 (605ms) are both clamped to
      // 350ms, so they start — and move — together.
      await _frames(tester, const Duration(milliseconds: 400));
      final six = _opacity(tester, _row(6));
      final seven = _opacity(tester, _row(7));
      final eleven = _opacity(tester, _row(11));
      expect(eleven, greaterThan(0));
      expect(eleven, seven);
      expect(six, greaterThan(seven));

      // Everything has arrived by maxDelay + duration (+ a frame of slack).
      await _frames(tester, const Duration(milliseconds: 350));
      for (var i = 0; i < 12; i++) {
        expect(_opacity(tester, _row(i)), 1, reason: 'row $i');
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('custom step, duration and maxDelay are honoured', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _rows(
          3,
          step: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 200),
          maxDelay: const Duration(seconds: 1),
        ),
        settle: Duration.zero,
      );
      await _frames(tester, const Duration(milliseconds: 192));
      expect(_opacity(tester, _row(0)), greaterThan(0.9));
      expect(_opacity(tester, _row(2)), 0, reason: 'row 2 waits 200ms');

      await _frames(tester, const Duration(milliseconds: 240));
      expect(_opacity(tester, _row(2)), 1);
    });

    testWidgets('rows at or past animateBelowIndex render bare', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _rows(14), settle: Duration.zero);
      for (final i in [0, 11]) {
        expect(_in(_row(i), FadeTransition), findsOneWidget, reason: 'row $i');
        expect(_in(_row(i), SlideTransition), findsOneWidget);
      }
      for (final i in [12, 13]) {
        expect(_in(_row(i), FadeTransition), findsNothing, reason: 'row $i');
        expect(_in(_row(i), SlideTransition), findsNothing);
        expect(
          _in(_row(i), StatefulWidget),
          findsNothing,
          reason: 'a bare row must not allocate a State',
        );
      }
      // Visible from the very first frame.
      expect(find.text('row 13').hitTestable(), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('animateBelowIndex: 0 disables the entrance entirely', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _rows(3, animateBelowIndex: 0),
        settle: Duration.zero,
      );
      expect(_in(find.byType(AnimatedListItem), FadeTransition), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a long list only animates the rows of the first screenful', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        ListView.builder(
          itemCount: 60,
          itemExtent: 48,
          itemBuilder: (_, i) => AnimatedListItem(
            key: ValueKey('row-$i'),
            index: i,
            child: Text('row $i'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(_row(50), 400);
      await tester.pumpAndSettle();
      expect(_row(50), findsOneWidget);
      expect(
        _in(find.byType(AnimatedListItem), FadeTransition),
        findsNothing,
        reason: 'rows scrolled into view must not animate',
      );
    });

    testWidgets('a negative index animates at once instead of throwing', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AnimatedListItem(
          key: ValueKey('row-0'),
          index: -3,
          child: Text('row'),
        ),
        settle: Duration.zero,
      );
      expect(tester.takeException(), isNull);
      await _frames(tester, const Duration(milliseconds: 48));
      expect(_opacity(tester, _row(0)), greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('removed before its delay elapses, it leaves no timer', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _rows(8), settle: Duration.zero);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(const SizedBox.shrink());
      // A leaked timer would fire into a disposed controller here — and the
      // framework fails the test for any timer still pending at the end.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the entrance ends: no frames are produced afterwards', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _rows(12), settle: Duration.zero);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the wrapped child stays interactive', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AnimatedListItem(
          index: 2,
          child: TextButton(onPressed: () => taps++, child: const Text('go')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('ScaleFadeIn behaviour', () {
    testWidgets('fades in and grows from 92% on mount', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ScaleFadeIn(child: Text('hello')),
        settle: Duration.zero,
      );
      expect(_fade(tester), 0);
      expect(_scale(tester), closeTo(0.92, 1e-9));

      await _frames(tester, const Duration(milliseconds: 160));
      expect(_fade(tester), inExclusiveRange(0, 1));
      expect(_scale(tester), greaterThan(0.92));

      await _frames(tester, const Duration(milliseconds: 320));
      expect(_fade(tester), 1);
      expect(_scale(tester), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('honours a custom duration', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ScaleFadeIn(
          duration: Duration(milliseconds: 100),
          child: Text('hello'),
        ),
        settle: Duration.zero,
      );
      await _frames(tester, const Duration(milliseconds: 112));
      expect(_fade(tester), 1);
      expect(_scale(tester), 1);
    });

    testWidgets('a delay holds it invisible until it elapses', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ScaleFadeIn(
          delay: Duration(milliseconds: 300),
          child: Text('hello'),
        ),
        settle: Duration.zero,
      );
      await _frames(tester, const Duration(milliseconds: 288));
      expect(_fade(tester), 0);
      expect(_scale(tester), closeTo(0.92, 1e-9));
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'waiting must not draw frames',
      );

      await _frames(tester, const Duration(milliseconds: 64));
      expect(_fade(tester), greaterThan(0));

      await tester.pumpAndSettle();
      expect(_fade(tester), 1);
      expect(_scale(tester), 1);
    });

    testWidgets('removed during its delay, it leaves no timer', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ScaleFadeIn(delay: Duration(seconds: 2), child: Text('hello')),
        settle: Duration.zero,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('removed mid-animation, it disposes cleanly', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ScaleFadeIn(child: Text('hello')),
        settle: Duration.zero,
      );
      await _frames(tester, const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
