import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/design/app_dimens.dart';
import 'package:location_gps/shared/widgets/progress_track.dart';

import 'widget_harness.dart';

const _track = Key('track');

/// The filled portion of the track under [of].
Finder _fill([Finder? of]) => find.descendant(
      of: of ?? find.byKey(_track),
      matching: find.byType(FractionallySizedBox),
    );

/// The semantics value the track announces.
String? _semanticValue(WidgetTester tester, [Finder? of]) => tester
    .widget<Semantics>(find
        .descendant(
          of: of ?? find.byKey(_track),
          matching: find.byType(Semantics),
        )
        .first)
    .properties
    .value;

/// A fixed-width track, so fill widths are exact.
Widget _sized(double value, {double width = 200, Gradient? gradient}) =>
    Center(
      child: SizedBox(
        width: width,
        child: ProgressTrack(
          key: _track,
          value: value,
          color: gradient == null ? Colors.teal : null,
          gradient: gradient,
        ),
      ),
    );

void main() {
  setUpAll(initHarness);

  group('ProgressTrack layout', () {
    testOnEverySurface(
      'empty, partial, full and over-full tracks fit a column and a row',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final v in const [0.0, 0.37, 1.0, 4.2, -3.0])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ProgressTrack(value: v, color: Colors.teal),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(LongText.of(s),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: ProgressTrack(
                    value: 0.5,
                    gradient: LinearGradient(
                      colors: [Colors.indigo, Colors.cyan],
                    ),
                    height: CompSz.headerTrackHeight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      verify: (tester, _) async {
        final tracks = find.byType(ProgressTrack);
        expect(tracks, findsNWidgets(6));
        for (final e in tracks.evaluate()) {
          final t = e.widget as ProgressTrack;
          expect(tester.getSize(find.byWidget(t)).height, t.height);
        }
      },
    );
  });

  group('ProgressTrack fill', () {
    for (final (value, expected) in const [
      (0.0, 0.0),
      (0.25, 50.0),
      (0.5, 100.0),
      (1.0, 200.0),
      // A raw ratio is clamped, never drawn past the end or backwards.
      (1.7, 200.0),
      (double.infinity, 200.0),
      (-0.3, 0.0),
    ]) {
      testWidgets('value $value fills ${expected}dp of 200dp', (tester) async {
        await pumpSurface(tester, phoneEn, _sized(value));
        expectCleanLayout(tester);
        expect(tester.getSize(_fill()).width, moreOrLessEquals(expected));
        expect(tester.getSize(find.byKey(_track)).width, 200);
      });
    }

    testWidgets('a NaN ratio (0 / 0) draws an empty track instead of throwing',
        (tester) async {
      // The leaderboards pass `count / maxCount`; a board whose leader has a
      // zero count divides 0 by 0.
      await pumpSurface(tester, phoneEn, _sized(0 / 0));
      expectCleanLayout(tester);
      expect(tester.getSize(_fill()).width, 0);
      expect(_semanticValue(tester), '0%');
    });

    testWidgets('fills from the reading start: left in en, right in ar',
        (tester) async {
      await pumpSurface(tester, phoneEn, _sized(0.25));
      final enTrack = tester.getRect(find.byKey(_track));
      final enFill = tester.getRect(_fill());
      expect(enFill.left, enTrack.left);
      expect(enFill.right, lessThan(enTrack.right));

      await pumpSurface(tester, phoneAr, _sized(0.25));
      final arTrack = tester.getRect(find.byKey(_track));
      final arFill = tester.getRect(_fill());
      expect(arFill.right, arTrack.right);
      expect(arFill.left, greaterThan(arTrack.left));
    });

    testWidgets('the fill is the full height of the track', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: SizedBox(
            width: 100,
            child: ProgressTrack(
              key: _track,
              value: 0.5,
              color: Colors.teal,
              height: 11,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_track)).height, 11);
      expect(tester.getSize(_fill()).height, 11);
    });

    testWidgets('default height is the design token', (tester) async {
      await pumpSurface(tester, phoneEn, _sized(0.5));
      expect(tester.getSize(find.byKey(_track)).height, CompSz.trackHeight);
    });
  });

  group('ProgressTrack colours', () {
    BoxDecoration trackDecoration(WidgetTester tester) => tester
        .widget<Container>(find.descendant(
          of: find.byKey(_track),
          matching: find.byType(Container),
        ))
        .decoration! as BoxDecoration;

    BoxDecoration fillDecoration(WidgetTester tester) => tester
        .widget<DecoratedBox>(find.descendant(
          of: _fill(),
          matching: find.byType(DecoratedBox),
        ))
        .decoration as BoxDecoration;

    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('the unfilled track is the theme container tone — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _sized(0.5));
        final context = tester.element(find.byKey(_track));
        expect(
          trackDecoration(tester).color,
          Theme.of(context).colorScheme.surfaceContainerHighest,
        );
        expect(fillDecoration(tester).color, Colors.teal);
        expect(fillDecoration(tester).gradient, isNull);
      });
    }

    testWidgets('a custom track colour replaces the theme tone',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const SizedBox(
          width: 100,
          child: ProgressTrack(
            key: _track,
            value: 0.5,
            color: Colors.teal,
            trackColor: Colors.white24,
          ),
        ),
      );
      expect(trackDecoration(tester).color, Colors.white24);
    });

    testWidgets('a gradient wins over a flat colour', (tester) async {
      const gradient = LinearGradient(colors: [Colors.indigo, Colors.cyan]);
      await pumpSurface(
        tester,
        phoneEn,
        const SizedBox(
          width: 100,
          child: ProgressTrack(
            key: _track,
            value: 0.5,
            color: Colors.red,
            gradient: gradient,
          ),
        ),
      );
      expect(fillDecoration(tester).gradient, gradient);
      expect(fillDecoration(tester).color, isNull);
    });

    testWidgets('both ends are rounded as pills', (tester) async {
      await pumpSurface(tester, phoneEn, _sized(0.5));
      final radius = BorderRadius.circular(Radii.pill);
      expect(trackDecoration(tester).borderRadius, radius);
      expect(fillDecoration(tester).borderRadius, radius);
    });

    test('needs a colour or a gradient', () {
      expect(() => ProgressTrack(value: 0.5), throwsAssertionError);
    });
  });

  group('ProgressTrack semantics', () {
    for (final (value, en, ar) in const [
      (0.0, '0%', '0٪'),
      (0.555, '56%', '56٪'),
      (1.0, '100%', '100٪'),
      (3.0, '100%', '100٪'),
      (-1.0, '0%', '0٪'),
    ]) {
      testWidgets('announces $value as a localized, clamped percentage',
          (tester) async {
        await pumpSurface(tester, phoneEn, _sized(value));
        expect(_semanticValue(tester), en);
        expect(en, l10n(english).unitPercentValue(en.replaceAll('%', '')));

        await pumpSurface(tester, phoneAr, _sized(value));
        expect(_semanticValue(tester), ar);
        expect(ar, l10n(arabic).unitPercentValue(ar.replaceAll('٪', '')));
      });
    }
  });
}
