import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/map_fab.dart';

import 'widget_harness.dart';

/// Two fabs stacked in the bottom-end corner of a map-sized box, the way the
/// visit map card lays them out.
Widget _overMap(Surface s, {VoidCallback? onTrail, VoidCallback? onDirections}) {
  final t = l10n(s.locale);
  return SizedBox(
    height: CompSz.mapCard,
    child: Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFFE5E5E5))),
        PositionedDirectional(
          end: Insets.x3,
          bottom: Insets.x3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapFab.rounded(
                key: const Key('trail'),
                icon: Icons.timeline,
                onTap: onTrail ?? () {},
                semanticLabel: t.trailOpenFull,
              ),
              const SizedBox(height: Insets.x2),
              MapFab.rounded(
                key: const Key('directions'),
                icon: Icons.assistant_direction,
                onTap: onDirections ?? () {},
                semanticLabel: t.mapOpenDirections,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(initHarness);

  testOnEverySurface(
    'two fabs over a map card fit and sit in the bottom-end corner',
    (s) => _overMap(s),
    verify: (tester, s) async {
      final map = tester.getRect(find.byType(Stack).first);
      final fab = tester.getRect(find.byKey(const Key('directions')));
      expect(fab.bottom, moreOrLessEquals(map.bottom - Insets.x3));
      if (s.isArabic) {
        expect(fab.left, moreOrLessEquals(map.left + Insets.x3));
      } else {
        expect(fab.right, moreOrLessEquals(map.right - Insets.x3));
      }
    },
  );

  group('MapFab behaviour', () {
    testWidgets('each fab fires its own callback once per tap',
        (tester) async {
      var trail = 0;
      var directions = 0;
      await pumpSurface(
        tester,
        phoneEn,
        _overMap(
          phoneEn,
          onTrail: () => trail++,
          onDirections: () => directions++,
        ),
      );
      await tester.tap(find.byKey(const Key('trail')));
      await tester.pump();
      expect((trail, directions), (1, 0));

      await tester.tap(find.byKey(const Key('directions')));
      await tester.pump();
      expect((trail, directions), (1, 1));
    });

    testWidgets('a tap just inside each edge of the target counts',
        (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: MapFab.rounded(
            icon: Icons.fit_screen,
            onTap: () => taps++,
            semanticLabel: 'Fit',
          ),
        ),
      );
      final rect = tester.getRect(find.byType(MapFab));
      // Edge midpoints: the rounded corners are outside the ink shape.
      for (final point in [
        rect.centerLeft + const Offset(1, 0),
        rect.centerRight - const Offset(1, 0),
        rect.topCenter + const Offset(0, 1),
        rect.bottomCenter - const Offset(0, 1),
      ]) {
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(taps, 4);
    });
  });

  group('MapFab accessibility', () {
    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('is announced as a labelled button — $surface',
          (tester) async {
        final handle = tester.ensureSemantics();
        final t = l10n(surface.locale);
        await pumpSurface(tester, surface, _overMap(surface));
        for (final (key, label) in [
          ('trail', t.trailOpenFull),
          ('directions', t.mapOpenDirections),
        ]) {
          expect(
            tester.getSemantics(find.byKey(Key(key))),
            containsSemantics(
              label: label,
              isButton: true,
              hasTapAction: true,
              isFocusable: true,
            ),
          );
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
        handle.dispose();
      });
    }

    for (final surface in surfaces) {
      testWidgets('the tap target is at least 48dp — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _overMap(surface));
        for (final key in const ['trail', 'directions']) {
          final size = tester.getSize(find.byKey(Key(key)));
          expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
          expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
          // The ink covers the whole target, not a smaller inner box.
          final ink = tester.getSize(find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(InkWell),
          ));
          expect(ink, size);
        }
      });
    }

    testWidgets('meets the Android tap-target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(tester, phoneEn, _overMap(phoneEn));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('MapFab theming', () {
    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('surface fill, primary glyph, rounded and raised — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _overMap(surface));
        final fab = find.byKey(const Key('trail'));
        final cs = Theme.of(tester.element(fab)).colorScheme;
        final material = tester.widget<Material>(
          find.descendant(of: fab, matching: find.byType(Material)).first,
        );
        expect(material.color, cs.surface);
        expect(material.elevation, greaterThan(0));
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(Radii.btn));
        // The ink clips to the same rounded shape.
        final ink = tester.widget<InkWell>(
          find.descendant(of: fab, matching: find.byType(InkWell)),
        );
        expect(ink.customBorder, shape);

        final icon = tester.widget<Icon>(
          find.descendant(of: fab, matching: find.byType(Icon)),
        );
        expect(icon.icon, Icons.timeline);
        expect(icon.color, cs.primary);
        // The glyph is centred in the target.
        expect(
          tester.getCenter(find.descendant(of: fab, matching: find.byType(Icon))),
          tester.getCenter(fab),
        );
      });
    }

    testWidgets('the physical shape casts a shadow in dark mode too',
        (tester) async {
      await pumpSurface(tester, surfaces[3], _overMap(surfaces[3]));
      final physical = tester.renderObject<RenderPhysicalShape>(find
          .descendant(
            of: find.byKey(const Key('trail')),
            matching: find.byType(PhysicalShape),
          )
          .first);
      expect(physical.elevation, greaterThan(0));
    });
  });
}
