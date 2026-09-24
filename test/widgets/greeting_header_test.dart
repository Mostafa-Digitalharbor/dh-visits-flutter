import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';
import 'package:location_gps/shared/widgets/greeting_header.dart';
import 'package:location_gps/shared/widgets/initial_avatar.dart';
import 'package:location_gps/shared/widgets/progress_track.dart';
import 'package:location_gps/shared/widgets/tone_pill.dart';

import 'widget_harness.dart';

const _wave = '👋';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

DateTime Function() _at(int hour, [int minute = 0]) =>
    () => DateTime(2026, 9, 17, hour, minute);

GreetingHeader _header(
  Surface s, {
  String? name,
  String? role,
  int done = 3,
  int total = 4,
  List<GreetingStat> stats = const [],
  DateTime Function()? now,
}) =>
    GreetingHeader(
      name: name ?? (s.isArabic ? 'سارة' : 'Sara'),
      roleLabel: role ?? l10n(s.locale).roleManager,
      roleIcon: Icons.shield_outlined,
      done: done,
      total: total,
      stats: stats,
      now: now ?? _at(9),
    );

/// "3/4 · 75%", assembled from the ARB pieces the widget uses.
String _progress(AppLocalizations t, String done, String total, String pct) =>
    '${t.commonFraction(done, total)}${t.commonListSeparator}'
    '${t.unitPercentValue(pct)}';

/// The two stats the manager dashboard passes, on a long, busy day.
List<GreetingStat> _dayStats(Surface s) {
  final t = l10n(s.locale);
  return [
    GreetingStat(
        icon: Icons.event_available, value: '1,200', label: t.dashboardKpiToday),
    GreetingStat(
        icon: Icons.timer_outlined,
        value: t.dashboardFieldHoursValue('812.5'),
        label: t.dashboardFieldTime),
  ];
}

/// More stats than any screen passes today, with the longest labels.
List<GreetingStat> _manyStats(Surface s) {
  final t = l10n(s.locale);
  return [
    ..._dayStats(s),
    GreetingStat(
        icon: Icons.pending_actions,
        value: '9,999',
        label: t.dashboardKpiPending),
  ];
}

/// The width [finder]'s widget would take if nothing constrained it.
double _naturalWidth(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).getMaxIntrinsicWidth(
        double.infinity);

void main() {
  setUpAll(initHarness);

  group('GreetingHeader layout', () {
    testOnEverySurface(
      'a long name, a long role, 1200/1200 and a busy day fit',
      (s) => Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: _header(
          s,
          name: s.isArabic ? LongText.arabicPerson : LongText.english,
          role: '${l10n(s.locale).roleManager} · ${LongText.of(s)}',
          done: 1200,
          total: 1200,
          stats: _dayStats(s),
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        final t = l10n(s.locale);
        final count = find.text(_progress(t, '1,200', '1,200', '100'));
        expect(count, findsOneWidget);
        // The count is the reason the header exists: it is never cut.
        expect(
          tester.renderObject<RenderParagraph>(count).didExceedMaxLines,
          isFalse,
        );
        // The name keeps a real share of the row next to a long role label.
        final card = tester.getRect(find.byType(GreetingHeader));
        final name = find.text(
            s.isArabic ? LongText.arabicPerson : LongText.english);
        expect(tester.getSize(name).width, greaterThan(card.width * 0.25));
        // Every piece of text is drawn inside the card.
        final texts = find.descendant(
            of: find.byType(GreetingHeader), matching: find.byType(Text));
        for (var i = 0; i < texts.evaluate().length; i++) {
          final r = tester.getRect(texts.at(i));
          expect(r.left, greaterThanOrEqualTo(card.left - 0.01));
          expect(r.right, lessThanOrEqualTo(card.right + 0.01));
        }
        for (final stat in _dayStats(s)) {
          expect(find.text(stat.value), findsOneWidget);
        }
      },
    );

    testOnEverySurface(
      'three stats with the longest labels fit',
      (s) => Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: _header(s, done: 45, total: 60, stats: _manyStats(s)),
      ),
      verify: (tester, s) async {
        final card = tester.getRect(find.byType(GreetingHeader));
        for (final stat in _manyStats(s)) {
          final value = tester.getRect(find.text(stat.value));
          expect(value.left, greaterThanOrEqualTo(card.left));
          expect(value.right, lessThanOrEqualTo(card.right));
        }
      },
    );

    testOnEverySurface(
      'no stats and no visits yet',
      (s) => Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: _header(s, done: 0, total: 0),
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(_progress(t, '0', '0', '0')), findsOneWidget);
        expect(find.byIcon(Icons.event_available), findsNothing);
        expect(tester.widget<ProgressTrack>(find.byType(ProgressTrack)).value,
            0);
      },
    );

    testOnEverySurface(
      'a single very long word as the name',
      (s) => Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: _header(s, name: 'عبدالرحمن' * 12, stats: _dayStats(s)),
      ),
    );
  });

  group('GreetingHeader greeting', () {
    const cases = <(int, int, String)>[
      (0, 0, 'morning'),
      (6, 30, 'morning'),
      (11, 59, 'morning'),
      (12, 0, 'afternoon'),
      (16, 59, 'afternoon'),
      (17, 0, 'evening'),
      (23, 59, 'evening'),
    ];

    String expected(AppLocalizations t, String part) => switch (part) {
          'morning' => t.commonGreetingMorning,
          'afternoon' => t.commonGreetingAfternoon,
          _ => t.commonGreetingEvening,
        };

    for (final s in [phoneEn, phoneAr]) {
      for (final (hour, minute, part) in cases) {
        final time =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        testWidgets('$time is $part — $s', (tester) async {
          await pumpSurface(
            tester,
            s,
            _header(s, now: _at(hour, minute)),
          );
          final greeting = expected(l10n(s.locale), part);
          expect(find.text('$greeting $_wave'), findsOneWidget);
        });
      }
    }

    testWidgets('English uses three distinct greetings', (tester) async {
      final t = l10n(english);
      expect(
        {
          t.commonGreetingMorning,
          t.commonGreetingAfternoon,
          t.commonGreetingEvening,
        },
        hasLength(3),
      );
    });

    testWidgets('the clock is read when the header builds', (tester) async {
      var hour = 9;
      Widget build() => _header(phoneEn, now: () => DateTime(2026, 1, 1, hour));
      await pumpSurface(tester, phoneEn, build());
      expect(find.text('${l10n(english).commonGreetingMorning} $_wave'),
          findsOneWidget);
      hour = 20;
      await pumpSurface(tester, phoneEn, build());
      expect(find.text('${l10n(english).commonGreetingEvening} $_wave'),
          findsOneWidget);
    });

    testWidgets('without an injected clock it shows one of the three',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const GreetingHeader(
          name: 'Sara',
          roleLabel: 'Manager',
          roleIcon: Icons.shield_outlined,
          done: 1,
          total: 2,
        ),
      );
      final t = l10n(english);
      final shown = [
        t.commonGreetingMorning,
        t.commonGreetingAfternoon,
        t.commonGreetingEvening,
      ].where((g) => find.text('$g $_wave').evaluate().isNotEmpty);
      expect(shown, hasLength(1));
    });
  });

  group('GreetingHeader progress', () {
    const cases = <(int, int, String, String, String, double)>[
      (3, 4, '3', '4', '75', 0.75),
      (2, 3, '2', '3', '67', 2 / 3),
      (1234, 1500, '1,234', '1,500', '82', 1234 / 1500),
      (0, 10, '0', '10', '0', 0),
      (10, 10, '10', '10', '100', 1),
      // More done than planned (a visit added mid-day): capped, not 120%.
      (6, 5, '6', '5', '100', 1),
      (0, 0, '0', '0', '0', 0),
      // Nonsense from the server must not throw or go below zero.
      (-2, 5, '-2', '5', '0', 0),
      (3, -4, '3', '-4', '0', 0),
    ];

    for (final (done, total, d, t, pct, value) in cases) {
      for (final s in [phoneEn, phoneAr]) {
        testWidgets('$done of $total reads $d/$t · $pct — $s', (tester) async {
          await pumpSurface(tester, s, _header(s, done: done, total: total));
          expect(find.text(_progress(l10n(s.locale), d, t, pct)),
              findsOneWidget);
          final track = tester.widget<ProgressTrack>(find.byType(ProgressTrack));
          expect(track.value, moreOrLessEquals(value));
        });
      }
    }

    for (final s in [phoneEn, phoneAr]) {
      testWidgets('the progress label is localized — $s', (tester) async {
        await pumpSurface(tester, s, _header(s));
        expect(find.text(l10n(s.locale).dashboardTodayProgress), findsOneWidget);
      });
    }

    testWidgets('a count that fits is drawn at its natural size',
        (tester) async {
      await pumpSurface(tester, phoneEn, _header(phoneEn, done: 3, total: 4));
      final count = find.text(_progress(l10n(english), '3', '4', '75'));
      expect(tester.getSize(count).width,
          moreOrLessEquals(_naturalWidth(tester, count)));
      final box = find.ancestor(of: count, matching: find.byType(FittedBox));
      expect(tester.getSize(box).width,
          moreOrLessEquals(_naturalWidth(tester, count)));
    });

    testWidgets('a count wider than the card scales down, whole',
        (tester) async {
      final s = surfaces[1]; // 320dp, en, 1.25×
      await pumpSurface(
        tester,
        s,
        Padding(
          padding: const EdgeInsets.all(Insets.x4),
          child: _header(s, done: 1200, total: 1200),
        ),
      );
      expectCleanLayout(tester);
      final count = find.text(_progress(l10n(english), '1,200', '1,200', '100'));
      final box = tester.getRect(
          find.ancestor(of: count, matching: find.byType(FittedBox)));
      final card = tester.getRect(find.byType(GreetingHeader));
      // Laid out at full width (nothing cut), drawn smaller to fit the card.
      expect(tester.getSize(count).width,
          moreOrLessEquals(_naturalWidth(tester, count)));
      expect(box.width, lessThan(_naturalWidth(tester, count)));
      expect(box.right, lessThanOrEqualTo(card.right));
      // The label gave up its room first.
      expect(tester.getSize(find.text(l10n(english).dashboardTodayProgress))
          .width, lessThan(1));
    });

    testWidgets('a stat value wider than its share scales down, whole',
        (tester) async {
      final s = surfaces[1]; // 320dp, en, 1.25×
      final stats = _dayStats(s);
      await pumpSurface(
        tester,
        s,
        Padding(
          padding: const EdgeInsets.all(Insets.x4),
          child: _header(s, stats: stats),
        ),
      );
      expectCleanLayout(tester);
      final hours = find.text(stats.last.value);
      final box = tester.getRect(
          find.ancestor(of: hours, matching: find.byType(FittedBox)));
      expect(box.width, lessThan(_naturalWidth(tester, hours)));
      expect(box.right,
          lessThanOrEqualTo(tester.getRect(find.byType(GreetingHeader)).right));
    });

    testWidgets('digits stay Latin in Arabic', (tester) async {
      await pumpSurface(tester, phoneAr, _header(phoneAr, done: 7, total: 9));
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('/'));
      expect(text, contains('7/9'));
      expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
    });
  });

  group('GreetingHeader content', () {
    testWidgets('shows the name, its initial and the role', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        _header(phoneAr, name: 'عبد الله', role: l10n(arabic).roleManager),
      );
      expect(find.text('عبد الله'), findsOneWidget);
      expect(tester.widget<InitialAvatar>(find.byType(InitialAvatar)).name,
          'عبد الله');
      expect(find.text('ع'), findsOneWidget);
      expect(find.text(l10n(arabic).roleManager), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      final pill = tester.widget<TonePill>(find.byType(TonePill));
      expect(pill.flexibleLabel, isTrue);
    });

    testWidgets('an empty name falls back to "?" without throwing',
        (tester) async {
      await pumpSurface(tester, phoneEn, _header(phoneEn, name: ''));
      expectCleanLayout(tester);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('each stat shows its icon, value and label, in order',
        (tester) async {
      final stats = _manyStats(phoneEn);
      await pumpSurface(tester, phoneEn, _header(phoneEn, stats: stats));
      var previous = double.negativeInfinity;
      for (final stat in stats) {
        expect(find.byIcon(stat.icon), findsOneWidget);
        expect(find.text(stat.label), findsOneWidget);
        final value = tester.getRect(find.text(stat.value));
        expect(value.left, greaterThan(previous));
        previous = value.left;
        // The value is never truncated; the label yields.
        expect(tester.widget<Text>(find.text(stat.value)).overflow, isNull);
        expect(tester.widget<Text>(find.text(stat.label)).overflow,
            TextOverflow.ellipsis);
      }
      // Stats sit under the progress bar.
      expect(tester.getRect(find.text(stats.first.value)).top,
          greaterThan(tester.getRect(find.byType(ProgressTrack)).bottom));
    });
  });

  group('GreetingHeader direction', () {
    testWidgets('the avatar leads and the role trails, mirrored in Arabic',
        (tester) async {
      Future<(double, double, double)> positions(Surface s) async {
        await pumpSurface(tester, s, _header(s, name: 'Sara'));
        return (
          tester.getCenter(find.byType(InitialAvatar)).dx,
          tester.getCenter(find.text('Sara')).dx,
          tester.getCenter(find.byType(TonePill)).dx,
        );
      }

      final (enAvatar, enName, enRole) = await positions(phoneEn);
      expect(enAvatar, lessThan(enName));
      expect(enName, lessThan(enRole));

      final (arAvatar, arName, arRole) = await positions(phoneAr);
      expect(arAvatar, greaterThan(arName));
      expect(arName, greaterThan(arRole));
    });

    testWidgets('the bar fills from the reading start', (tester) async {
      /// The filled part and the whole track, on [s].
      Future<(Rect, Rect)> fill(Surface s) async {
        await pumpSurface(tester, s, _header(s, done: 1, total: 4));
        final bar = tester.getRect(find.descendant(
          of: find.byType(ProgressTrack),
          matching: find.byType(DecoratedBox),
        ).last);
        return (bar, tester.getRect(find.byType(ProgressTrack)));
      }

      final (en, enTrack) = await fill(phoneEn);
      expect(en.width, moreOrLessEquals(enTrack.width / 4));
      expect(en.left, moreOrLessEquals(enTrack.left));
      final (ar, arTrack) = await fill(phoneAr);
      expect(ar.width, moreOrLessEquals(arTrack.width / 4));
      expect(ar.right, moreOrLessEquals(arTrack.right));
    });
  });

  group('GreetingHeader theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('the card uses the theme brand gradient — $s',
          (tester) async {
        await pumpSurface(tester, s, _header(s));
        final context = tester.element(find.byType(GreetingHeader));
        expect(Theme.of(context).brightness, s.brightness);
        final card = tester.widget<Container>(find
            .descendant(
                of: find.byType(GreetingHeader),
                matching: find.byType(Container))
            .first);
        final decoration = card.decoration! as BoxDecoration;
        expect(decoration.gradient, context.x.brandGradient);
        expect(decoration.boxShadow, context.x.elev2);
        expect(decoration.borderRadius, BorderRadius.circular(Radii.xl));

        // Text on the gradient is white; captions are a step dimmer.
        final name = tester.widget<Text>(find.text(s.isArabic ? 'سارة' : 'Sara'));
        expect(name.style!.color, AppColors.onMap);
        final greeting = tester.widget<Text>(find.text(
            '${l10n(s.locale).commonGreetingMorning} $_wave'));
        expect(greeting.style!.color,
            AppColors.onMap.withValues(alpha: Alphas.onBrandMuted));
      });
    }

    testWidgets('light and dark gradients differ', (tester) async {
      await pumpSurface(tester, phoneEn, _header(phoneEn));
      final light =
          tester.element(find.byType(GreetingHeader)).x.brandGradient;
      await pumpSurface(tester, _phoneArDark, _header(_phoneArDark));
      final dark = tester.element(find.byType(GreetingHeader)).x.brandGradient;
      expect(light, isNot(dark));
    });
  });
}
