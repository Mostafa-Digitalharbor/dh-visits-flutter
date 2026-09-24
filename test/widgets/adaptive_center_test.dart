import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/adaptive_center.dart';

import 'widget_harness.dart';

const _bottom = Key('placeholder-action');
const _box = Key('box');

/// The block the empty / error states centre: a big glyph, a long sentence
/// and an action underneath it.
Widget _placeholder(Surface s, {double glyph = 160}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.inbox_outlined, size: glyph),
    const SizedBox(height: 24),
    Text(
      '${LongText.of(s)} ${LongText.of(s)} ${LongText.arabicPerson}',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 24),
    FilledButton(
      key: _bottom,
      onPressed: () {},
      child: Text(l10n(s.locale).commonRetry),
    ),
  ],
);

Finder get _scrollable => find.descendant(
  of: find.byType(AdaptiveCenter),
  matching: find.byType(Scrollable),
);

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(_scrollable).position;

void main() {
  setUpAll(initHarness);

  group('AdaptiveCenter layout', () {
    testOnEverySurface(
      'a placeholder taller than the body scrolls instead of overflowing',
      (s) => AdaptiveCenter(
        padding: const EdgeInsets.all(24),
        child: _placeholder(s, glyph: 260),
      ),
      verify: (tester, s) async {
        expect(_scrollable, findsOneWidget);
        // The action under the fold is reachable — the whole point.
        await tester.scrollUntilVisible(
          find.byKey(_bottom),
          80,
          scrollable: _scrollable,
        );
        final bottom = tester.getBottomLeft(find.byKey(_bottom)).dy;
        expect(bottom, lessThanOrEqualTo(s.size.height));
      },
    );

    testOnEverySurface(
      'a placeholder inside a list shrink-wraps without a nested viewport',
      (s) => ListView(
        children: [
          Text(LongText.of(s)),
          AdaptiveCenter(
            padding: const EdgeInsets.all(16),
            child: _placeholder(s),
          ),
        ],
      ),
      verify: (tester, s) async {
        expect(
          find.descendant(
            of: find.byType(AdaptiveCenter),
            matching: find.byType(SingleChildScrollView),
          ),
          findsNothing,
        );
      },
    );

    testOnEverySurface(
      'a block that fits is pinned to the centre of the body',
      (s) => const AdaptiveCenter(
        child: SizedBox(key: _box, width: 120, height: 80),
      ),
      verify: (tester, s) async {
        final body = tester.getCenter(find.byType(AdaptiveCenter));
        final box = tester.getCenter(find.byKey(_box));
        expect(box.dx, moreOrLessEquals(body.dx));
        expect(box.dy, moreOrLessEquals(body.dy));
        expect(_position(tester).maxScrollExtent, 0);
      },
    );
  });

  group('AdaptiveCenter behaviour', () {
    Widget sized(double height, Widget child) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 300, height: height, child: child),
    );

    testWidgets('too tall: scrolls by exactly the excess, padding included', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        sized(
          300,
          const AdaptiveCenter(
            padding: EdgeInsets.all(20),
            child: SizedBox(key: _box, width: 100, height: 500),
          ),
        ),
      );
      final viewport = tester.getRect(find.byType(AdaptiveCenter));
      expect(_position(tester).maxScrollExtent, 500 + 40 - 300);

      // The padding scrolls with the content: 20dp above it at the start…
      expect(tester.getTopLeft(find.byKey(_box)).dy - viewport.top, 20);

      // …and 20dp below it at the end.
      _position(tester).jumpTo(_position(tester).maxScrollExtent);
      await tester.pump();
      expect(viewport.bottom - tester.getBottomLeft(find.byKey(_box)).dy, 20);
      expectCleanLayout(tester);
    });

    testWidgets('a narrow tall child stays horizontally centred', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        sized(
          200,
          const AdaptiveCenter(
            child: SizedBox(key: _box, width: 100, height: 600),
          ),
        ),
      );
      expect(
        tester.getCenter(find.byKey(_box)).dx,
        moreOrLessEquals(tester.getCenter(find.byType(AdaptiveCenter)).dx),
      );
    });

    testWidgets('switches to scrolling when the viewport shrinks (rotation)', (
      tester,
    ) async {
      Widget build(double h) => sized(
        h,
        const AdaptiveCenter(
          child: SizedBox(key: _box, width: 100, height: 400),
        ),
      );
      await pumpSurface(tester, phoneEn, build(700));
      expect(_position(tester).maxScrollExtent, 0);
      expect(
        tester.getCenter(find.byKey(_box)).dy,
        moreOrLessEquals(tester.getCenter(find.byType(AdaptiveCenter)).dy),
      );

      await pumpSurface(tester, phoneEn, build(250));
      expect(_position(tester).maxScrollExtent, 150);
      expectCleanLayout(tester);

      // And back: centred again, nothing left to scroll.
      await pumpSurface(tester, phoneEn, build(700));
      expect(_position(tester).maxScrollExtent, 0);
      expectCleanLayout(tester);
    });

    testWidgets(
      'unbounded height: centres horizontally and keeps the padding',
      (tester) async {
        await pumpSurface(
          tester,
          phoneEn,
          ListView(
            children: const [
              AdaptiveCenter(
                padding: EdgeInsets.only(top: 30),
                child: SizedBox(key: _box, width: 100, height: 100),
              ),
            ],
          ),
        );
        expectCleanLayout(tester);
        final host = tester.getRect(find.byType(AdaptiveCenter));
        final box = tester.getRect(find.byKey(_box));
        expect(box.center.dx, moreOrLessEquals(host.center.dx));
        expect(box.top - host.top, 30);
        // Shrink-wrapped: the host is only as tall as the content.
        expect(host.height, 130);
      },
    );

    testWidgets('unbounded height inside a Column does not throw', (
      tester,
    ) async {
      // A bare Column gives its children unbounded height too — the case a
      // nested viewport would crash on.
      await pumpSurface(
        tester,
        phoneEn,
        const SingleChildScrollView(
          child: Column(
            children: [AdaptiveCenter(child: SizedBox(key: _box, height: 50))],
          ),
        ),
      );
      expectCleanLayout(tester);
      expect(find.byKey(_box), findsOneWidget);
    });

    testWidgets('directional padding mirrors in Arabic', (tester) async {
      Future<double> offsetFromCentre(Surface s) async {
        await pumpSurface(
          tester,
          s,
          const AdaptiveCenter(
            padding: EdgeInsetsDirectional.only(start: 80),
            child: SizedBox(key: _box, width: 60, height: 60),
          ),
        );
        return tester.getCenter(find.byKey(_box)).dx -
            tester.getCenter(find.byType(AdaptiveCenter)).dx;
      }

      expect(await offsetFromCentre(phoneEn), moreOrLessEquals(40));
      expect(await offsetFromCentre(phoneAr), moreOrLessEquals(-40));
    });

    testWidgets('an empty child renders without errors', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AdaptiveCenter(child: SizedBox.shrink()),
      );
      expectCleanLayout(tester);
      expect(_position(tester).maxScrollExtent, 0);
    });

    testWidgets('the scrolled content stays interactive', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        const Surface('landscape', size: Size(720, 360), locale: english),
        AdaptiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 600),
              TextButton(
                key: _bottom,
                onPressed: () => taps++,
                child: const Text('go'),
              ),
            ],
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(_bottom),
        100,
        scrollable: _scrollable,
      );
      await tester.tap(find.byKey(_bottom));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
