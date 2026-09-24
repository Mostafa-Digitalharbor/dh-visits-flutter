import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/inline_empty_row.dart';

import 'widget_harness.dart';

const _small = Surface('small · en', size: Size(320, 568), locale: english);
const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

Finder get _row => find.byType(InlineEmptyRow);

/// The row inside a card, which is where every screen puts it.
Widget _inCard(Widget child) => Card(
      margin: const EdgeInsets.all(Insets.x4),
      child: Padding(
        padding: const EdgeInsets.all(Insets.x4),
        child: child,
      ),
    );

void main() {
  setUpAll(initHarness);

  group('InlineEmptyRow layout', () {
    testOnEverySurface(
      'a long localized sentence wraps inside a card',
      (s) => _inCard(
        InlineEmptyRow(
          text: '${l10n(s.locale).customersEmpty} ${LongText.of(s)} '
              '${LongText.of(s)}',
        ),
      ),
      verify: (tester, s) async {
        // The historic bug: without Expanded the sentence ran off the card.
        final card = tester.getRect(find.byType(Card));
        final text = tester.getRect(find.byType(Text));
        expect(text.right, lessThanOrEqualTo(card.right));
        expect(text.left, greaterThanOrEqualTo(card.left));
        expect(text.height,
            greaterThan(tester.getSize(find.byType(Icon)).height));
      },
    );

    testOnEverySurface(
      'a single unbreakable token fits',
      (s) => _inCard(InlineEmptyRow(text: 'VIS/${'0' * 120}')),
    );

    testOnEverySurface(
      'several rows stack in a narrow column',
      (s) => SizedBox(
        width: 160,
        child: Column(
          children: [
            for (final icon in [Icons.inbox_outlined, Icons.event_busy, Icons.people_outline])
              InlineEmptyRow(icon: icon, text: l10n(s.locale).customersEmpty),
          ],
        ),
      ),
    );
  });

  group('InlineEmptyRow content', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('shows the localized text — $s', (tester) async {
        await pumpSurface(
          tester,
          s,
          InlineEmptyRow(text: l10n(s.locale).customersEmpty),
        );
        expect(find.text(l10n(s.locale).customersEmpty), findsOneWidget);
        expect(tester.widget<Text>(find.byType(Text)).maxLines, isNull);
      });
    }

    testWidgets('the default glyph is the inbox', (tester) async {
      await pumpSurface(tester, phoneEn, const InlineEmptyRow(text: 't'));
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('a custom glyph replaces it', (tester) async {
      await pumpSurface(tester, phoneEn,
          const InlineEmptyRow(text: 't', icon: Icons.attach_file));
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('an empty text still lays out', (tester) async {
      await pumpSurface(
          tester, phoneEn, const Column(children: [InlineEmptyRow(text: '')]));
      expectCleanLayout(tester);
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('InlineEmptyRow sizing', () {
    for (final (s, scale) in [(_small, 0.85), (phoneEn, 1.0)]) {
      testWidgets('glyph, gap and padding scale with the width — $s',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          const Column(children: [InlineEmptyRow(text: 't')]),
        );
        expect(tester.widget<Icon>(find.byType(Icon)).size,
            moreOrLessEquals(IconSz.label * scale));
        final padding = tester.widget<Padding>(
            find.descendant(of: _row, matching: find.byType(Padding)).first);
        expect(padding.padding,
            EdgeInsets.symmetric(vertical: Insets.x2 * scale));
        final gap = tester.getRect(find.text('t')).left -
            tester.getRect(find.byType(Icon)).right;
        expect(gap, moreOrLessEquals(Insets.x2 * scale));
      });
    }
  });

  group('InlineEmptyRow direction', () {
    testWidgets('the glyph leads in both directions', (tester) async {
      await pumpSurface(
          tester, phoneEn, const InlineEmptyRow(text: 'nothing here'));
      final en = (tester.getCenter(find.byType(Icon)).dx,
          tester.getCenter(find.text('nothing here')).dx);
      await pumpSurface(
          tester, phoneAr, const InlineEmptyRow(text: 'nothing here'));
      final ar = (tester.getCenter(find.byType(Icon)).dx,
          tester.getCenter(find.text('nothing here')).dx);
      expect(en.$1, lessThan(en.$2));
      expect(ar.$1, greaterThan(ar.$2));
      expect(tester.getRect(find.byType(Icon)).right,
          moreOrLessEquals(phoneAr.size.width));
    });
  });

  group('InlineEmptyRow theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('glyph and text share the muted theme colour — $s',
          (tester) async {
        await pumpSurface(tester, s, const InlineEmptyRow(text: 't'));
        final context = tester.element(_row);
        final theme = Theme.of(context);
        expect(theme.brightness, s.brightness);
        final muted = theme.colorScheme.onSurfaceVariant;
        expect(tester.widget<Icon>(find.byType(Icon)).color, muted);
        final style = tester.widget<Text>(find.text('t')).style!;
        expect(style.color, muted);
        expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize);
      });
    }
  });
}
