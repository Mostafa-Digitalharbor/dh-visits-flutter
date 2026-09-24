import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/info_row.dart';

import 'widget_harness.dart';

const _small = Surface('small · en', size: Size(320, 568), locale: english);
const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

/// A URL-like token with no break opportunities.
final _longWord = 'https://maps.example.com/${'x' * 180}';

Finder get _row => find.byType(InfoRow);

/// The tinted circle behind the glyph.
Finder get _dot => find
    .ancestor(of: find.byType(Icon), matching: find.byType(Container))
    .first;

void main() {
  setUpAll(initHarness);

  group('InfoRow layout', () {
    testOnEverySurface(
      'long wrapping text, a very long word and an empty line fit',
      (s) => Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: Column(
          children: [
            InfoRow(
              icon: Icons.business,
              text: '${LongText.of(s)} ${LongText.of(s)}',
            ),
            InfoRow(icon: Icons.link, text: _longWord),
            const InfoRow(icon: Icons.notes, text: ''),
            InfoRow(
              icon: Icons.person,
              text: LongText.arabicPerson,
              textStyle: const TextStyle(fontSize: 22),
            ),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        // The long text wraps inside the row rather than being cut.
        final text = find.text('${LongText.of(s)} ${LongText.of(s)}');
        expect(tester.getSize(text).height,
            greaterThan(tester.getSize(_dot).height));
        expect(tester.widget<Text>(text).maxLines, isNull);
        for (var i = 0; i < 4; i++) {
          expect(tester.getRect(_row.at(i)).right,
              lessThanOrEqualTo(s.size.width - Insets.x4 + 0.01));
        }
      },
    );
  });

  group('InfoRow content', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('shows the glyph and the text — $s', (tester) async {
        final text = l10n(s.locale).customersEmpty;
        await pumpSurface(tester, s, InfoRow(icon: Icons.phone, text: text));
        expect(find.text(text), findsOneWidget);
        expect(find.byIcon(Icons.phone), findsOneWidget);
      });
    }

    testWidgets('the default style is the theme bodyMedium', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const InfoRow(icon: Icons.phone, text: 't'),
      );
      final context = tester.element(_row);
      expect(tester.widget<Text>(find.text('t')).style,
          Theme.of(context).textTheme.bodyMedium);
    });

    testWidgets('textStyle replaces it', (tester) async {
      const style = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
      await pumpSurface(
        tester,
        phoneEn,
        const InfoRow(icon: Icons.phone, text: 't', textStyle: style),
      );
      expect(tester.widget<Text>(find.text('t')).style, style);
    });

    testWidgets('an empty text keeps the row as tall as its circle',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Column(children: [InfoRow(icon: Icons.phone, text: '')]),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(_row).height,
          moreOrLessEquals(CompSz.infoDot + 2 * Insets.x1h));
    });

    testWidgets('the circle stays centred against multi-line text',
        (tester) async {
      await pumpSurface(
        tester,
        _small,
        Column(
          children: [
            InfoRow(icon: Icons.place, text: '${LongText.english} ' * 3),
          ],
        ),
      );
      final text = tester.getRect(find.byType(Text));
      expect(tester.getCenter(_dot).dy,
          moreOrLessEquals(text.center.dy, epsilon: 0.5));
    });
  });

  group('InfoRow sizing', () {
    for (final (s, scale) in [(_small, 0.85), (phoneEn, 1.0)]) {
      testWidgets('circle, glyph and padding scale with the width — $s',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          const Column(children: [InfoRow(icon: Icons.phone, text: 't')]),
        );
        expect(tester.getSize(_dot),
            Size.square(CompSz.infoDot * scale));
        expect(tester.widget<Icon>(find.byType(Icon)).size,
            moreOrLessEquals(IconSz.pill * scale));
        final padding = tester.widget<Padding>(find
            .descendant(of: _row, matching: find.byType(Padding))
            .first);
        expect(padding.padding,
            EdgeInsets.symmetric(vertical: Insets.x1h * scale));
        // Gap between circle and text.
        final gap = tester.getRect(find.text('t')).left -
            tester.getRect(_dot).right;
        expect(gap, moreOrLessEquals(Insets.x2h * scale));
      });
    }

    testWidgets('the circle ignores the text scale', (tester) async {
      await pumpSurface(
        tester,
        surfaces[1], // 320dp · en · 1.25×
        const Column(children: [InfoRow(icon: Icons.phone, text: 't')]),
      );
      expect(tester.getSize(_dot), Size.square(CompSz.infoDot * 0.85));
    });
  });

  group('InfoRow direction', () {
    testWidgets('the circle leads in both directions', (tester) async {
      await pumpSurface(
          tester, phoneEn, const InfoRow(icon: Icons.phone, text: 'text'));
      final en = (tester.getCenter(_dot).dx,
          tester.getCenter(find.text('text')).dx);
      await pumpSurface(
          tester, phoneAr, const InfoRow(icon: Icons.phone, text: 'text'));
      final ar = (tester.getCenter(_dot).dx,
          tester.getCenter(find.text('text')).dx);
      expect(en.$1, lessThan(en.$2));
      expect(ar.$1, greaterThan(ar.$2));
      // The circle hugs the reading start edge.
      expect(tester.getRect(_dot).right,
          moreOrLessEquals(phoneAr.size.width));
    });
  });

  group('InfoRow theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('circle and glyph colours come from the theme — $s',
          (tester) async {
        await pumpSurface(
            tester, s, const InfoRow(icon: Icons.phone, text: 't'));
        final context = tester.element(_row);
        final cs = Theme.of(context).colorScheme;
        expect(Theme.of(context).brightness, s.brightness);
        final decoration =
            tester.widget<Container>(_dot).decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color,
            cs.primaryContainer.withValues(alpha: Alphas.disabled));
        expect(tester.widget<Icon>(find.byType(Icon)).color,
            cs.onPrimaryContainer);
      });
    }
  });
}
