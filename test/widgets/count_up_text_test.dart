import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/count_up_text.dart';

import 'widget_harness.dart';

const _style = TextStyle(fontSize: 28, fontWeight: FontWeight.w800);
const _frame = Duration(milliseconds: 16);

/// The text the widget currently shows.
String _shown(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(CountUpText),
        matching: find.byType(Text),
      ),
    )
    .data!;

bool _animates(WidgetTester tester) => find
    .descendant(
      of: find.byType(CountUpText),
      matching: find.byType(TweenAnimationBuilder<double>),
    )
    .evaluate()
    .isNotEmpty;

/// Records the shown text on every frame until [total] has elapsed.
Future<List<String>> _record(WidgetTester tester, Duration total) async {
  final seen = [_shown(tester)];
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(_frame);
    elapsed += _frame;
    seen.add(_shown(tester));
  }
  return seen;
}

int _leadingInt(String s) =>
    int.parse(RegExp(r'^\d+').firstMatch(s)!.group(0)!);

Future<void> _pump(WidgetTester tester, Widget child, {Surface s = phoneEn}) =>
    pumpSurface(tester, s, Center(child: child), settle: Duration.zero);

void main() {
  setUpAll(initHarness);

  group('CountUpText layout', () {
    testOnEverySurface(
      'a KPI tile with a large figure and a long caption fits',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            for (final value in [
              '1234567',
              l10n(s.locale).unitPercentValue('100'),
              l10n(s.locale).unitKm('9999'),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: CountUpText(
                        value,
                        style: const TextStyle(fontSize: 34, height: 1),
                      ),
                    ),
                    Text(
                      LongText.of(s),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      verify: (tester, s) async {
        await tester.pumpAndSettle();
        expect(find.text('1234567'), findsOneWidget);
        expect(
          find.text(l10n(s.locale).unitPercentValue('100')),
          findsOneWidget,
        );
        expect(find.text(l10n(s.locale).unitKm('9999')), findsOneWidget);
      },
    );
  });

  group('CountUpText counting', () {
    testWidgets('counts from 0 up to the value, never backwards', (
      tester,
    ) async {
      await _pump(tester, const CountUpText('27'));
      expect(_shown(tester), '0');
      final seen = await _record(tester, AppDurations.countUp);
      expect(seen.last, '27');
      final numbers = seen.map(int.parse).toList();
      for (var i = 1; i < numbers.length; i++) {
        expect(numbers[i], greaterThanOrEqualTo(numbers[i - 1]));
      }
      expect(
        numbers.toSet().length,
        greaterThan(5),
        reason: 'it should visibly count, not jump',
      );
      await tester.pump(_frame);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('eases out: most of the way there by half time', (
      tester,
    ) async {
      await _pump(tester, const CountUpText('1000'));
      await tester.pump(AppDurations.countUp ~/ 2);
      final mid = int.parse(_shown(tester));
      expect(mid, (1000 * Curves.easeOutCubic.transform(0.5)).round());
      expect(mid, lessThan(1000));
    });

    testWidgets('takes the default countUp duration', (tester) async {
      await _pump(tester, const CountUpText('5000'));
      await tester.pump(
        AppDurations.countUp - const Duration(milliseconds: 50),
      );
      expect(_shown(tester), isNot('5000'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_shown(tester), '5000');
    });

    testWidgets('honours a custom duration', (tester) async {
      await _pump(
        tester,
        const CountUpText('40', duration: Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shown(tester), isNot('40'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shown(tester), '40');
    });

    testWidgets('zero stays zero', (tester) async {
      await _pump(tester, const CountUpText('0'));
      final seen = await _record(tester, AppDurations.countUp);
      expect(seen.toSet(), {'0'});
    });

    testWidgets('a huge count lands on exactly the figure it was given', (
      tester,
    ) async {
      // Counting runs through a double, which cannot hold every integer past
      // 2^53 — the last frame must still be the real figure.
      for (final value in [
        '123456789',
        '9007199254740993',
        '9223372036854775807',
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, CountUpText(value));
        await tester.pumpAndSettle();
        expect(_shown(tester), value);
      }
    });

    testWidgets('a figure beyond 64 bits is shown as it is', (tester) async {
      const value = '99999999999999999999';
      await _pump(tester, const CountUpText(value));
      expect(_animates(tester), isFalse);
      expect(_shown(tester), value);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the last frame is the value verbatim, as without animation', (
      tester,
    ) async {
      for (final value in ['007', ' 27 ', '05%']) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, CountUpText(value));
        expect(_animates(tester), isTrue, reason: value);
        await tester.pumpAndSettle();
        expect(_shown(tester), value);
      }
    });
  });

  group('CountUpText units', () {
    for (final (value, zero) in [
      ('92%', '0%'),
      ('92٪', '0٪'),
      ('92 %', '0 %'),
      ('12 km', '0 km'),
      ('12 كم', '0 كم'),
      ('42 km/h', '0 km/h'),
      ('7 visits', '0 visits'),
    ]) {
      testWidgets('keeps the unit while counting: "$value"', (tester) async {
        await _pump(tester, CountUpText(value));
        expect(_shown(tester), zero);
        final seen = await _record(tester, AppDurations.countUp);
        final unit = zero.substring(1);
        expect(seen, everyElement(endsWith(unit)));
        expect(seen.map(_leadingInt).toSet().length, greaterThan(2));
        expect(seen.last, value);
      });
    }

    for (final s in [phoneEn, phoneAr]) {
      testWidgets('counts the app\'s own localized figures — $s', (
        tester,
      ) async {
        final t = l10n(s.locale);
        for (final value in [
          t.unitPercentValue('75'),
          t.unitKm('12'),
          t.unitMeters('850'),
          t.unitKmh('42'),
        ]) {
          // A fresh widget each time: an updated one counts on from the
          // figure it was showing (covered below).
          await tester.pumpWidget(const SizedBox.shrink());
          await _pump(tester, CountUpText(value), s: s);
          expect(_animates(tester), isTrue, reason: value);
          expect(_leadingInt(_shown(tester)), 0);
          await tester.pumpAndSettle();
          expect(_shown(tester), value);
        }
        expect(t.unitPercentValue('75'), s.isArabic ? '75٪' : '75%');
      });
    }
  });

  group('CountUpText non-counting values', () {
    for (final value in [
      '00:58', // a clock
      '3.5', // a decimal
      '3.5 km',
      '0.0',
      '1,234', // grouped
      '-5', // negative
      '−3', // typographic minus, as AppNumber.signed writes it
      '+5',
      '٢٧', // Arabic-Indic digits
      '10x2', // a unit holding a digit
      'N/A',
      '',
      '—',
    ]) {
      testWidgets('shows "$value" as it is, at once', (tester) async {
        await _pump(tester, CountUpText(value, style: _style));
        expect(_animates(tester), isFalse);
        expect(_shown(tester), value);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('CountUpText behaviour', () {
    testWidgets('reduced motion shows the final figure at once', (
      tester,
    ) async {
      await _pump(
        tester,
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: CountUpText('92%', style: _style),
        ),
      );
      expect(_animates(tester), isFalse);
      expect(_shown(tester), '92%');
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the style reaches the text, animated or not', (tester) async {
      for (final value in ['27', '00:58']) {
        await _pump(tester, CountUpText(value, style: _style));
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byType(CountUpText),
            matching: find.byType(Text),
          ),
        );
        expect(text.style, _style, reason: value);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a new value counts on from the current one', (tester) async {
      await _pump(tester, const CountUpText('27'));
      await tester.pumpAndSettle();
      expect(_shown(tester), '27');

      await _pump(tester, const CountUpText('30'));
      expect(_shown(tester), '27', reason: 'no drop back to zero');
      final seen = await _record(tester, AppDurations.countUp);
      expect(seen.map(int.parse), everyElement(inInclusiveRange(27, 30)));
      expect(seen.last, '30');
    });

    testWidgets('a smaller new value counts down to it', (tester) async {
      await _pump(tester, const CountUpText('30'));
      await tester.pumpAndSettle();
      await _pump(tester, const CountUpText('10'));
      await tester.pumpAndSettle();
      expect(_shown(tester), '10');
    });

    testWidgets('switching to a non-countable value shows it at once', (
      tester,
    ) async {
      await _pump(tester, const CountUpText('27'));
      await tester.pump(const Duration(milliseconds: 100));
      await _pump(tester, const CountUpText('00:58'));
      expect(_animates(tester), isFalse);
      expect(_shown(tester), '00:58');
    });

    testWidgets('removed mid-count, it disposes cleanly', (tester) async {
      await _pump(tester, const CountUpText('500'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(AppDurations.countUp);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('screen readers get the final figure once settled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const CountUpText('92%'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('92%'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('renders in dark mode with the theme text colour', (
      tester,
    ) async {
      final dark = surfaces[2];
      await _pump(tester, const CountUpText('27'), s: dark);
      await tester.pumpAndSettle();
      final context = tester.element(find.text('27'));
      expect(Theme.of(context).brightness, Brightness.dark);
      final rendered = tester.renderObject<RenderParagraph>(find.text('27'));
      expect(
        rendered.text.style?.color,
        DefaultTextStyle.of(context).style.color,
      );
    });
  });
}
