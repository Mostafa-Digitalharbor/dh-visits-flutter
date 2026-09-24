import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/app_refresh_indicator.dart';

import 'widget_harness.dart';

Widget _list(Surface s, {int count = 30}) => ListView.builder(
  itemCount: count,
  itemBuilder: (_, i) => ListTile(
    title: Text('${LongText.of(s)} #$i'),
    subtitle: Text(LongText.arabicPerson),
  ),
);

Finder get _spinner => find.byType(RefreshProgressIndicator);

/// Pulls the list down far enough to trigger a refresh and lets the
/// indicator reach its "refreshing" position. The trigger distance is a
/// share of the viewport height, so the pull scales with the screen.
Future<void> _pull(WidgetTester tester) async {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  await tester.fling(
    find.byType(Scrollable).first,
    Offset(0, height * 0.6),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1)); // scroll settles
  await tester.pump(const Duration(seconds: 1)); // indicator snaps in
}

/// Lets the indicator hide once the refresh has completed.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(initHarness);

  group('AppRefreshIndicator layout', () {
    testOnEverySurface(
      'a pulled list with long rows shows the spinner without layout errors',
      (s) => AppRefreshIndicator(
        onRefresh: () => Completer<void>().future,
        child: _list(s),
      ),
      verify: (tester, s) async {
        await _pull(tester);
        expect(_spinner, findsOneWidget);
        // The disc sits inside the viewport, below the top edge.
        final disc = tester.getRect(_spinner);
        expect(disc.top, greaterThanOrEqualTo(0));
        expect(disc.right, lessThanOrEqualTo(s.size.width));
      },
    );
  });

  group('AppRefreshIndicator behaviour', () {
    testWidgets('pulling down calls onRefresh once and hides when done', (
      tester,
    ) async {
      var calls = 0;
      final done = Completer<void>();
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () {
            calls++;
            return done.future;
          },
          child: _list(phoneEn),
        ),
      );
      await _pull(tester);
      expect(calls, 1);
      expect(_spinner, findsOneWidget, reason: 'spinner while refreshing');

      done.complete();
      await _finish(tester);
      expect(_spinner, findsNothing);
      expect(calls, 1);
    });

    testWidgets('a second pull while refreshing does not call again', (
      tester,
    ) async {
      var calls = 0;
      final done = Completer<void>();
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () {
            calls++;
            return done.future;
          },
          child: _list(phoneEn),
        ),
      );
      await _pull(tester);
      await _pull(tester);
      expect(calls, 1);
      done.complete();
      await _finish(tester);

      // Once finished, a new pull refreshes again.
      await _pull(tester);
      expect(calls, 2);
      await _finish(tester);
    });

    testWidgets('scrolling the list up does not refresh', (tester) async {
      var calls = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () async => calls++,
          child: _list(phoneEn),
        ),
      );
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(_spinner, findsNothing);
    });

    testWidgets('a short list that does not fill the screen still refreshes', (
      tester,
    ) async {
      var calls = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () async => calls++,
          child: _list(phoneEn, count: 1),
        ),
      );
      await _pull(tester);
      await _finish(tester);
      expect(calls, 1);
    });

    testWidgets('renders its child untouched', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            children: [
              TextButton(onPressed: () => taps++, child: const Text('row')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('row'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the spinner is announced in the UI language', (tester) async {
      for (final s in [phoneEn, phoneAr]) {
        await pumpSurface(
          tester,
          s,
          AppRefreshIndicator(
            onRefresh: () => Completer<void>().future,
            child: _list(s),
          ),
        );
        await _pull(tester);
        final label = MaterialLocalizations.of(
          tester.element(_spinner),
        ).refreshIndicatorSemanticLabel;
        expect(
          tester.widget<RefreshProgressIndicator>(_spinner).semanticsLabel,
          label,
        );
        expect(label, s.isArabic ? 'إعادة تحميل' : 'Refresh');
        // Replace the tree so the pending refresh is dropped with it.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('AppRefreshIndicator theming', () {
    for (final s in [phoneEn, surfaces[2]]) {
      testWidgets('brand stroke on the surface disc — $s', (tester) async {
        await pumpSurface(
          tester,
          s,
          AppRefreshIndicator(onRefresh: () async {}, child: _list(s)),
        );
        final indicator = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        final scheme = Theme.of(
          tester.element(find.byType(RefreshIndicator)),
        ).colorScheme;
        expect(scheme.brightness, s.brightness);
        expect(indicator.color, scheme.primary);
        expect(indicator.backgroundColor, scheme.surface);
        expect(indicator.strokeWidth, 2.4);
        expect(indicator.displacement, 56);
      });
    }

    testWidgets('the visible spinner uses those colours', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppRefreshIndicator(
          onRefresh: () => Completer<void>().future,
          child: _list(phoneEn),
        ),
      );
      await _pull(tester);
      final spinner = tester.widget<RefreshProgressIndicator>(_spinner);
      final scheme = Theme.of(tester.element(_spinner)).colorScheme;
      expect(spinner.backgroundColor, scheme.surface);
      expect(spinner.valueColor?.value, scheme.primary);
      expect(spinner.strokeWidth, 2.4);
    });
  });
}
