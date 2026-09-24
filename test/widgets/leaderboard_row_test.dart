import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/shared/widgets/initial_avatar.dart';
import 'package:location_gps/shared/widgets/leaderboard_row.dart';
import 'package:location_gps/shared/widgets/progress_track.dart';

import 'widget_harness.dart';

const _green = Color(0xFF1E8E3E);
const _longEnglishPerson = 'Maximilian Alexander Konstantinopoulos-Worthington';

/// "92% · 12" the way the analytics board builds it.
String _rateAndCount(Surface s, int pct, int count) {
  final t = l10n(s.locale);
  return '${AppNumber.percent(t, pct)}${t.commonListSeparator}'
      '${AppNumber.whole(count)}';
}

String _person(Surface s) =>
    s.isArabic ? LongText.arabicPerson : _longEnglishPerson;

/// The disc a rank numeral is drawn on.
Finder _medalOf(String numeral) => find
    .ancestor(of: find.text(numeral), matching: find.byType(Container))
    .first;

BoxDecoration _decorationOf(WidgetTester tester, Finder container) =>
    tester.widget<Container>(container).decoration! as BoxDecoration;

Widget _row({
  Key? key,
  int rank = 5,
  String? avatarName = 'Sara',
  String name = 'Sara Ahmed',
  String figure = 'x',
  double value = 0.5,
  LeaderFigurePlacement placement = LeaderFigurePlacement.trailing,
}) =>
    Padding(
      padding: const EdgeInsets.all(16),
      child: LeaderboardRow(
        key: key,
        leading: RankMedalAvatar(name: avatarName, rank: rank),
        name: name,
        figure: figure,
        value: value,
        color: _green,
        placement: placement,
      ),
    );

void main() {
  setUpAll(initHarness);

  group('LeaderboardRow layout', () {
    testOnEverySurface(
      'an analytics board (inline figures, ranks 1–3 and 3-digit) fits',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (rank, pct, count) in const [
              (1, 100, 12),
              (2, 92, 1234),
              (3, 0, 0),
              (100, 47, 3),
              (1000, 5, 99),
            ])
              LeaderboardRow(
                leading: RankMedalAvatar(name: _person(s), rank: rank),
                name: _person(s),
                figure: _rateAndCount(s, pct, count),
                value: pct / 100,
                color: _green,
                placement: LeaderFigurePlacement.inline,
              ),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byType(LeaderboardRow), findsNWidgets(5));
        // The name gives way; the figure is never cut.
        for (final e in find.byType(LeaderboardRow).evaluate()) {
          final row = e.widget as LeaderboardRow;
          final figure = tester.renderObject<RenderParagraph>(find.descendant(
            of: find.byWidget(row),
            matching: find.text(row.figure),
          ));
          expect(
            figure.size.width,
            moreOrLessEquals(figure.getMaxIntrinsicWidth(double.infinity)),
          );
        }
      },
    );

    testOnEverySurface(
      'a dashboard board (trailing counts, icon discs) with long names fits',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final count in const [1234567, 12, 0])
              LeaderboardRow(
                leading: const CircleAvatar(
                  radius: 15,
                  child: Icon(Icons.store_rounded, size: 14),
                ),
                name: LongText.of(s),
                figure: AppNumber.whole(count),
                value: count / 1234567,
                color: _green,
              ),
            // A very long single word cannot wrap and must still ellipsize.
            LeaderboardRow(
              leading: RankMedalAvatar(name: '   ', rank: 4),
              name: 'W' * 120,
              figure: AppNumber.whole(0),
              value: 0 / 0,
              color: _green,
            ),
          ],
        ),
      ),
      scrollable: true,
    );
  });

  group('LeaderboardRow placement', () {
    testWidgets('trailing puts the figure after the bar, centred on the row',
        (tester) async {
      await pumpSurface(tester, phoneEn, _row(figure: '1,234'));
      final figure = tester.getRect(find.text('1,234'));
      final track = tester.getRect(find.byType(ProgressTrack));
      final row = tester.getRect(find.byType(LeaderboardRow));
      expect(figure.left, greaterThan(track.right));
      expect(figure.center.dy, moreOrLessEquals(row.center.dy, epsilon: 1));
    });

    testWidgets('inline puts the figure on the name line, above the bar',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(figure: '92% · 12', placement: LeaderFigurePlacement.inline),
      );
      final figure = tester.getRect(find.text('92% · 12'));
      final name = tester.getRect(find.text('Sara Ahmed'));
      final track = tester.getRect(find.byType(ProgressTrack));
      expect(figure.bottom, lessThanOrEqualTo(track.top));
      expect(figure.center.dy, moreOrLessEquals(name.center.dy, epsilon: 2));
      // The name takes the rest of the line; the figure ends where the bar ends.
      expect(figure.right, moreOrLessEquals(track.right));
    });

    for (final placement in LeaderFigurePlacement.values) {
      testWidgets('${placement.name}: a long name ellipsizes before the figure',
          (tester) async {
        await pumpSurface(
          tester,
          surfaces[0], // 320dp, ar, 1.25x
          _row(
            name: LongText.arabicCompany,
            figure: _rateAndCount(surfaces[0], 100, 1234),
            placement: placement,
          ),
        );
        expectCleanLayout(tester);
        final name = tester.renderObject<RenderParagraph>(
          find.text(LongText.arabicCompany),
        );
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(name.didExceedMaxLines, isTrue);
        final nameRect = tester.getRect(find.text(LongText.arabicCompany));
        final figureRect = tester.getRect(
          find.text(_rateAndCount(surfaces[0], 100, 1234)),
        );
        // RTL: the figure sits to the left of the name.
        expect(figureRect.right, lessThanOrEqualTo(nameRect.left));
      });
    }

    testWidgets('the leading badge is at the reading start in both languages',
        (tester) async {
      await pumpSurface(tester, phoneEn, _row());
      final enLead = tester.getCenter(find.byType(RankMedalAvatar));
      final enName = tester.getCenter(find.text('Sara Ahmed'));
      expect(enLead.dx, lessThan(enName.dx));

      await pumpSurface(tester, phoneAr, _row());
      final arLead = tester.getCenter(find.byType(RankMedalAvatar));
      final arName = tester.getCenter(find.text('Sara Ahmed'));
      expect(arLead.dx, greaterThan(arName.dx));
    });
  });

  group('LeaderboardRow value and colour', () {
    for (final (value, share) in const [
      (0.0, 0.0),
      (0.5, 0.5),
      (1.0, 1.0),
      (1.8, 1.0),
      (-2.0, 0.0),
    ]) {
      testWidgets('value $value fills ${share * 100}% of the bar',
          (tester) async {
        await pumpSurface(tester, phoneEn, _row(value: value));
        final track = tester.getSize(find.byType(ProgressTrack)).width;
        final fill = tester
            .getSize(find.descendant(
              of: find.byType(ProgressTrack),
              matching: find.byType(FractionallySizedBox),
            ))
            .width;
        expect(fill, moreOrLessEquals(track * share));
      });
    }

    testWidgets('an all-zero board (0 / 0) shows empty bars, not full ones',
        (tester) async {
      await pumpSurface(tester, phoneEn, _row(value: 0 / 0));
      expectCleanLayout(tester);
      final fill = find.descendant(
        of: find.byType(ProgressTrack),
        matching: find.byType(FractionallySizedBox),
      );
      expect(tester.getSize(fill).width, 0);
    });

    testWidgets('the colour tints the bar and the figure', (tester) async {
      await pumpSurface(tester, phoneEn, _row(figure: '27'));
      expect(tester.widget<ProgressTrack>(find.byType(ProgressTrack)).color,
          _green);
      final figure = tester.widget<Text>(find.text('27'));
      expect(figure.style?.color, _green);
      expect(figure.style?.fontWeight, FontWeight.w800);
      expect(figure.maxLines, 1);
    });

    testWidgets('figures are tabular so the column stays aligned',
        (tester) async {
      await pumpSurface(tester, phoneEn, _row(figure: '27'));
      expect(
        tester.widget<Text>(find.text('27')).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('RankMedalAvatar', () {
    for (final (rank, colour) in const [
      (1, AppColors.medalGold),
      (2, AppColors.medalSilver),
      (3, AppColors.medalBronze),
    ]) {
      for (final surface in [phoneEn, surfaces[2]]) {
        testWidgets('rank $rank is a metal disc with a white numeral — $surface',
            (tester) async {
          await pumpSurface(tester, surface, _row(rank: rank));
          expect(_decorationOf(tester, _medalOf('$rank')).color, colour);
          expect(
            tester.widget<Text>(find.text('$rank')).style?.color,
            AppColors.onMap,
          );
        });
      }
    }

    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('rank 4+ uses theme tones that stay legible — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _row(rank: 12));
        final cs = Theme.of(tester.element(find.text('12'))).colorScheme;
        final disc = _decorationOf(tester, _medalOf('12'));
        expect(disc.color, cs.onSurfaceVariant);
        expect(tester.widget<Text>(find.text('12')).style?.color, cs.surface);
        // Ringed in the card colour so it reads as sitting on the avatar.
        expect((disc.border! as Border).top.color, cs.surfaceContainerLowest);
        expect(disc.shape, BoxShape.circle);
      });
    }

    for (final rank in const [9, 10, 99, 100, 999, 1000]) {
      testWidgets('rank $rank is drawn whole inside its disc on a 320dp phone',
          (tester) async {
        await pumpSurface(tester, surfaces[0], _row(rank: rank));
        expectCleanLayout(tester);
        final numeral = AppNumber.whole(rank);
        final paragraph =
            tester.renderObject<RenderParagraph>(find.text(numeral));
        // Not clipped: laid out at its natural width…
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01),
        );
        // …and painted within the disc.
        final disc = tester.getRect(_medalOf(numeral)).inflate(0.01);
        final text = tester.getRect(find.text(numeral));
        expect(disc.contains(text.topLeft), isTrue, reason: '$text in $disc');
        expect(disc.contains(text.bottomRight), isTrue,
            reason: '$text in $disc');
      });
    }

    testWidgets('the numeral ignores the OS text size; the disc is fixed',
        (tester) async {
      await pumpSurface(tester, surfaces[1], _row(rank: 7));
      expect(
        tester.widget<Text>(find.text('7')).textScaler,
        TextScaler.noScaling,
      );
      final context = tester.element(find.text('7'));
      final expected = CompSz.medal *
          Responsive(context).widthScale; // 320dp → clamped scale
      expect(tester.getSize(_medalOf('7')).width, moreOrLessEquals(expected));
    });

    testWidgets('the medal overhangs the top trailing corner, mirrored in ar',
        (tester) async {
      await pumpSurface(tester, phoneEn, _row(rank: 1));
      var avatar = tester.getRect(find.byType(InitialAvatar));
      var medal = tester.getRect(_medalOf('1'));
      expect(medal.right, moreOrLessEquals(avatar.right + 2));
      expect(medal.top, moreOrLessEquals(avatar.top - 2));

      await pumpSurface(tester, phoneAr, _row(rank: 1));
      avatar = tester.getRect(find.byType(InitialAvatar));
      medal = tester.getRect(_medalOf('1'));
      expect(medal.left, moreOrLessEquals(avatar.left - 2));
      expect(medal.top, moreOrLessEquals(avatar.top - 2));
    });

    for (final name in const [null, '', '   ']) {
      testWidgets('a ${name == null ? 'null' : 'blank'} name shows "?"',
          (tester) async {
        await pumpSurface(tester, phoneEn, _row(rank: 2, avatarName: name));
        expectCleanLayout(tester);
        expect(find.text('?'), findsOneWidget);
      });
    }

    testWidgets('the avatar uses the initial of a real name', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        _row(rank: 2, avatarName: '  ${LongText.arabicPerson}'),
      );
      expect(find.text('ع'), findsOneWidget);
    });
  });
}
