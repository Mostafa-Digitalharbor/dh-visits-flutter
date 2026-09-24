import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/inline_notice.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_harness.dart';

const _small = Surface('small · en', size: Size(320, 568), locale: english);
const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

Finder get _notice => find.byType(InlineNotice);

Container _panel(WidgetTester tester) => tester.widget<Container>(
    find.descendant(of: _notice, matching: find.byType(Container)).first);

Icon _icon(WidgetTester tester) => tester.widget<Icon>(find.byType(Icon));

/// A notice inside a form, between other fields.
Widget _inForm(Widget notice) => Padding(
      padding: const EdgeInsets.all(Insets.x4),
      child: Column(
        children: [
          const TextField(),
          const SizedBox(height: Insets.x3),
          notice,
          const SizedBox(height: Insets.x3),
          const TextField(),
        ],
      ),
    );

void main() {
  setUpAll(initHarness);

  group('InlineNotice layout', () {
    for (final tone in NoticeTone.values) {
      testOnEverySurface(
        '${tone.name} with a long paragraph fits',
        (s) => _inForm(InlineNotice(
          tone: tone,
          text: '${l10n(s.locale).errUnknown} ${LongText.of(s)}',
        )),
        scrollable: true,
        verify: (tester, s) async {
          final panel = tester.getRect(_notice);
          // Full width of its slot, whatever the text length.
          expect(panel.width,
              moreOrLessEquals(s.size.width - 2 * Insets.x4));
          final text = tester.getRect(find.descendant(
              of: _notice, matching: find.byType(Text)));
          expect(text.right, lessThanOrEqualTo(panel.right));
          expect(text.left, greaterThanOrEqualTo(panel.left));
          expect(text.height,
              greaterThan(tester.getSize(find.byType(Icon)).height));
        },
      );
    }

    testOnEverySurface(
      'a one-word notice still fills the width',
      (s) => _inForm(const InlineNotice(text: 'OK')),
      verify: (tester, s) async {
        expect(tester.getSize(_notice).width,
            moreOrLessEquals(s.size.width - 2 * Insets.x4));
      },
    );

    testOnEverySurface(
      'an unbreakable token fits',
      (s) => _inForm(InlineNotice(
          tone: NoticeTone.error, text: 'https://${'x' * 150}.example.com')),
    );
  });

  group('InlineNotice tones', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('info: quiet container colours and an info glyph — $s',
          (tester) async {
        await pumpSurface(tester, s, _inForm(const InlineNotice(text: 't')));
        final cs = Theme.of(tester.element(_notice)).colorScheme;
        expect(Theme.of(tester.element(_notice)).brightness, s.brightness);
        final d = _panel(tester).decoration! as BoxDecoration;
        expect(d.color, cs.surfaceContainer);
        expect(_icon(tester).icon, Symbols.info);
        expect(_icon(tester).color, cs.onSurfaceVariant);
        expect(tester.widget<Text>(find.text('t')).style!.color,
            cs.onSurfaceVariant);
      });

      testWidgets('warning: the theme warning hue on its tint — $s',
          (tester) async {
        await pumpSurface(tester, s,
            _inForm(const InlineNotice(text: 't', tone: NoticeTone.warning)));
        final x = tester.element(_notice).x;
        final d = _panel(tester).decoration! as BoxDecoration;
        expect(d.color, x.warning.withValues(alpha: Alphas.tint));
        expect(_icon(tester).icon, Symbols.warning);
        expect(_icon(tester).color, x.warning);
        expect(tester.widget<Text>(find.text('t')).style!.color, x.warning);
      });

      testWidgets('error: the error container pair and an error glyph — $s',
          (tester) async {
        await pumpSurface(tester, s,
            _inForm(const InlineNotice(text: 't', tone: NoticeTone.error)));
        final cs = Theme.of(tester.element(_notice)).colorScheme;
        final d = _panel(tester).decoration! as BoxDecoration;
        expect(d.color, cs.errorContainer);
        expect(_icon(tester).icon, Symbols.error);
        expect(_icon(tester).color, cs.onErrorContainer);
        expect(tester.widget<Text>(find.text('t')).style!.color,
            cs.onErrorContainer);
      });
    }

    testWidgets('the three tones look different', (tester) async {
      final seen = <Color?>{};
      for (final tone in NoticeTone.values) {
        await pumpSurface(
            tester, phoneEn, _inForm(InlineNotice(text: 't', tone: tone)));
        seen.add((_panel(tester).decoration! as BoxDecoration).color);
      }
      expect(seen, hasLength(3));
    });

    testWidgets('the default tone is info', (tester) async {
      expect(const InlineNotice(text: 't').tone, NoticeTone.info);
    });

    testWidgets('a custom icon replaces the glyph but keeps the tone colour',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _inForm(const InlineNotice(
          text: 't',
          tone: NoticeTone.error,
          icon: Icons.lock_outline,
        )),
      );
      final cs = Theme.of(tester.element(_notice)).colorScheme;
      expect(_icon(tester).icon, Icons.lock_outline);
      expect(_icon(tester).color, cs.onErrorContainer);
    });

    testWidgets('the glyph is filled and scales with the width',
        (tester) async {
      await pumpSurface(tester, _small, _inForm(const InlineNotice(text: 't')));
      expect(_icon(tester).fill, 1);
      expect(_icon(tester).size, moreOrLessEquals(IconSz.xs * 0.85));
      final d = _panel(tester).decoration! as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(Radii.sm));
    });
  });

  group('InlineNotice structure', () {
    testWidgets('the glyph aligns with the first line of a long paragraph',
        (tester) async {
      await pumpSurface(
        tester,
        _small,
        _inForm(InlineNotice(text: '${LongText.english} ' * 3)),
      );
      final icon = tester.getRect(find.byType(Icon));
      final text = tester.getRect(
          find.descendant(of: _notice, matching: find.byType(Text)));
      expect(icon.top, moreOrLessEquals(text.top, epsilon: 1));
      expect(text.bottom, greaterThan(icon.bottom + 10));
    });

    for (final s in [phoneEn, phoneAr]) {
      testWidgets('shows the localized text — $s', (tester) async {
        final text = l10n(s.locale).errUnknown;
        await pumpSurface(tester, s, _inForm(InlineNotice(text: text)));
        expect(find.text(text), findsOneWidget);
        expect(tester.widget<Text>(find.text(text)).maxLines, isNull);
      });
    }

    testWidgets('the glyph leads in both directions', (tester) async {
      await pumpSurface(tester, phoneEn, _inForm(const InlineNotice(text: 'x')));
      final en = (tester.getCenter(find.byType(Icon)).dx,
          tester.getCenter(find.text('x')).dx);
      await pumpSurface(tester, phoneAr, _inForm(const InlineNotice(text: 'x')));
      final ar = (tester.getCenter(find.byType(Icon)).dx,
          tester.getCenter(find.text('x')).dx);
      expect(en.$1, lessThan(en.$2));
      expect(ar.$1, greaterThan(ar.$2));
    });

    testWidgets('an empty text still lays out', (tester) async {
      await pumpSurface(tester, phoneEn, _inForm(const InlineNotice(text: '')));
      expectCleanLayout(tester);
    });
  });

  group('InlineNotice accessibility', () {
    for (final tone in NoticeTone.values) {
      final live = tone == NoticeTone.error;
      testWidgets(
          '${tone.name} is ${live ? '' : 'not '}announced as a live region',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSurface(
          tester,
          phoneEn,
          _inForm(InlineNotice(text: 'Sync failed.', tone: tone)),
        );
        final node = tester.getSemantics(find.text('Sync failed.'));
        expect(node.label, 'Sync failed.');
        expect(
          node,
          live
              ? containsSemantics(label: 'Sync failed.', isLiveRegion: true)
              : isNot(containsSemantics(isLiveRegion: true)),
        );
        // The live region is the notice itself, not the whole form.
        if (live) {
          expect(node.rect.height,
              lessThan(tester.getSize(find.byType(Column).first).height));
        }
        handle.dispose();
      });
    }

    testWidgets('an error that changes its text stays a live region',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(tester, phoneEn,
          _inForm(const InlineNotice(text: 'First', tone: NoticeTone.error)));
      await pumpSurface(tester, phoneEn,
          _inForm(const InlineNotice(text: 'Second', tone: NoticeTone.error)));
      expect(
        tester.getSemantics(find.text('Second')),
        containsSemantics(label: 'Second', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
