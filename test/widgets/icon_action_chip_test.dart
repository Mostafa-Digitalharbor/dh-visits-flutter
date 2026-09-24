import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/icon_action_chip.dart';

import 'widget_harness.dart';

const _small = Surface('small · en', size: Size(320, 568), locale: english);
const _phoneArDark = Surface(
  'phone · ar · dark',
  size: Size(390, 844),
  locale: arabic,
  brightness: Brightness.dark,
);

/// `context.r()`'s width factor for [s].
double _widthScale(Surface s) => (s.size.width / 390).clamp(0.85, 1.2);

Finder get _chip => find.byType(IconActionChip);
Finder get _panel => find.descendant(of: _chip, matching: find.byType(Ink));
Finder get _inkWell =>
    find.descendant(of: _chip, matching: find.byType(InkWell));

/// A chip in a Row, the way both app bars host it.
Widget _inRow(IconActionChip chip) => Row(children: [chip]);

void main() {
  setUpAll(initHarness);

  group('IconActionChip layout', () {
    testOnEverySurface(
      'three chips beside a long title fit an app-bar row',
      (s) => SizedBox(
        height: 56,
        child: Row(
          children: [
            IconActionChip(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () {},
            ),
            Expanded(
              child: Text(
                LongText.of(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconActionChip(
              icon: Icons.search,
              tooltip: l10n(s.locale).commonSearch,
              onTap: () {},
            ),
            IconActionChip(
              icon: Icons.refresh,
              tooltip: l10n(s.locale).commonRetry,
              onTap: () {},
            ),
          ],
        ),
      ),
      verify: (tester, s) async {
        final side = CompSz.chip * _widthScale(s);
        for (var i = 0; i < 3; i++) {
          // The panel scales with the device; the target never drops below
          // 48dp and hugs the panel when the panel is bigger.
          expect(tester.getSize(_panel.at(i)), Size(side, side));
          final target = tester.getSize(_chip.at(i));
          final expected = side > IconSz.hit ? side : IconSz.hit;
          expect(target.width, moreOrLessEquals(expected));
          expect(target.height, moreOrLessEquals(expected));
          // The panel is centred in its target.
          expect(
            tester.getCenter(_panel.at(i)),
            offsetMoreOrLessEquals(tester.getCenter(_chip.at(i))),
          );
        }
        expect(
          tester.getRect(_chip.last).right,
          lessThanOrEqualTo(s.size.width),
        );
      },
    );

    testOnEverySurface(
      'a chip with an unread badge in a Stack keeps its size',
      (s) => Row(
        children: [
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconActionChip(
                icon: Icons.notifications_none,
                tooltip: 'x',
                onTap: () {},
              ),
              const PositionedDirectional(end: -2, top: -2, child: Text('99+')),
            ],
          ),
        ],
      ),
      verify: (tester, s) async {
        final size = tester.getSize(_chip);
        expect(size.width, lessThanOrEqualTo(CompSz.chip * 1.2));
        expect(size.height, lessThanOrEqualTo(CompSz.chip * 1.2));
      },
    );
  });

  group('IconActionChip taps', () {
    testWidgets('a tap on the panel fires onTap once', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(IconActionChip(icon: Icons.add, onTap: () => taps++)),
      );
      await tester.tap(_panel);
      await tester.pump();
      expect(taps, 1);
    });

    for (final s in [_small, phoneEn]) {
      testWidgets('the ring between panel and 48dp target is tappable — $s', (
        tester,
      ) async {
        // Regression: only the panel (34dp on a 320dp phone) answered taps.
        var taps = 0;
        await pumpSurface(
          tester,
          s,
          Center(
            child: IconActionChip(
              icon: Icons.add,
              tooltip: 'Add',
              onTap: () => taps++,
            ),
          ),
        );
        final target = tester.getRect(_chip);
        final panel = tester.getRect(_panel);
        expect(target.width, IconSz.hit);
        expect(panel.width, lessThan(IconSz.hit));
        final corners = [
          target.topLeft + const Offset(1, 1),
          target.topRight + const Offset(-1, 1),
          target.bottomLeft + const Offset(1, -1),
          target.bottomRight + const Offset(-1, -1),
        ];
        for (final point in corners) {
          expect(panel.contains(point), isFalse);
          await tester.tapAt(point);
          await tester.pump();
        }
        expect(taps, corners.length);
      });
    }

    testWidgets('a tap just outside the 48dp target does nothing', (
      tester,
    ) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: IconActionChip(icon: Icons.add, onTap: () => taps++),
        ),
      );
      final target = tester.getRect(_chip);
      await tester.tapAt(target.topLeft - const Offset(2, 2));
      await tester.tapAt(target.bottomRight + const Offset(2, 2));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('in a bounded parent the target stays 48dp, not the parent', (
      tester,
    ) async {
      // Regression: a plain Center grew to fill a bounded parent, and the
      // whole parent became the tap and semantics area.
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: SizedBox.square(
            dimension: 200,
            child: Stack(
              children: [IconActionChip(icon: Icons.add, onTap: () => taps++)],
            ),
          ),
        ),
      );
      expect(tester.getSize(_chip), const Size(IconSz.hit, IconSz.hit));
      final box = tester.getRect(find.byType(Stack).last);
      await tester.tapAt(box.bottomRight - const Offset(10, 10));
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('repeated taps each fire once', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(IconActionChip(icon: Icons.add, onTap: () => taps++)),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(_chip);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(taps, 3);
    });

    testWidgets('a long-press shows the tooltip and does not tap', (
      tester,
    ) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneAr,
        _inRow(
          IconActionChip(
            icon: Icons.settings,
            tooltip: l10n(arabic).profileTitle,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text(l10n(arabic).profileTitle), findsNothing);
      await tester.longPress(_chip);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(l10n(arabic).profileTitle), findsOneWidget);
      expect(taps, 0);
      // Let the tooltip dismiss so no timer outlives the test.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(l10n(arabic).profileTitle), findsNothing);
    });
  });

  group('IconActionChip ripple', () {
    testWidgets('the ripple paints on the chip\'s own transparent Material', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(IconActionChip(icon: Icons.add, onTap: () {})),
      );
      final host = tester.widget<Material>(
        find.ancestor(of: _inkWell, matching: find.byType(Material)).first,
      );
      expect(host.type, MaterialType.transparency);
      // The panel is ink on that Material, under the InkWell — not an
      // opaque box over it that would hide the splash.
      expect(
        find.descendant(of: _inkWell, matching: find.byType(Ink)),
        findsOneWidget,
      );

      final ink = Material.of(tester.element(_inkWell));
      expect(ink, isNot(paints..circle()));
      final gesture = await tester.startGesture(tester.getCenter(_panel));
      await tester.pump(const Duration(milliseconds: 100));
      expect(ink, paints..circle());
      await gesture.up();
      // The fade-out's ticker starts on the frame after the release.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(ink, isNot(paints..circle()));
    });

    testWidgets('the ripple is clipped to the panel radius', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(IconActionChip(icon: Icons.add, onTap: () {})),
      );
      final well = tester.widget<InkWell>(_inkWell);
      expect(well.borderRadius, BorderRadius.circular(Radii.sm));
    });
  });

  group('IconActionChip accessibility', () {
    testWidgets('with a tooltip: a labelled button with one tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(
          IconActionChip(
            icon: Icons.settings,
            tooltip: 'Settings',
            onTap: () {},
          ),
        ),
      );
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Settings');
      final node = tester.getSemantics(_inkWell);
      expect(
        node,
        matchesSemantics(
          tooltip: 'Settings',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          textDirection: TextDirection.ltr,
        ),
      );
      // The node covers the whole 48dp target, not just the panel.
      expect(node.rect.size, const Size(IconSz.hit, IconSz.hit));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('a semantics tap fires onTap once', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(
          IconActionChip(
            icon: Icons.settings,
            tooltip: 'Settings',
            onTap: () => taps++,
          ),
        ),
      );
      tester.semantics.tap(
        find.semantics.byPredicate((node) => node.tooltip == 'Settings'),
      );
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('without a tooltip there is no Tooltip, still a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        _inRow(IconActionChip(icon: Icons.add, onTap: () {})),
      );
      expect(find.byType(Tooltip), findsNothing);
      expect(
        tester.getSemantics(_inkWell),
        containsSemantics(isButton: true, hasTapAction: true, tooltip: ''),
      );
      handle.dispose();
    });

    testWidgets(
      'the glyph ignores the text scale, the target does not shrink',
      (tester) async {
        await pumpSurface(
          tester,
          surfaces.first, // 320dp · 1.25×
          _inRow(IconActionChip(icon: Icons.add, onTap: () {})),
        );
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, moreOrLessEquals(IconSz.chip * 0.85));
        expect(tester.getSize(_chip), const Size(IconSz.hit, IconSz.hit));
      },
    );
  });

  group('IconActionChip theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('panel and glyph colours come from the theme — $s', (
        tester,
      ) async {
        await pumpSurface(
          tester,
          s,
          _inRow(IconActionChip(icon: Icons.add, onTap: () {})),
        );
        final context = tester.element(_chip);
        final cs = Theme.of(context).colorScheme;
        expect(Theme.of(context).brightness, s.brightness);

        expect(
          tester.widget<Icon>(find.byType(Icon)).color,
          cs.onSurfaceVariant,
        );
        final panel = tester.widget<Ink>(_panel).decoration! as BoxDecoration;
        expect(panel.color, cs.surfaceContainerLowest);
        expect((panel.border! as Border).top.color, context.x.outlineVariant);
        expect(panel.borderRadius, BorderRadius.circular(Radii.sm));
        expect(panel.boxShadow, context.x.elev1);
      });
    }
  });
}
