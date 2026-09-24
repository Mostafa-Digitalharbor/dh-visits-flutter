import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/skeleton.dart';
import 'package:shimmer/shimmer.dart';

import 'widget_harness.dart';

BoxDecoration _decoration(WidgetTester tester, Finder of) => tester
    .widget<Container>(
        find.descendant(of: of, matching: find.byType(Container)).first)
    .decoration! as BoxDecoration;

/// Every skeleton shape under one shimmer, the way a loading screen groups
/// them. Shimmer animates forever: tests pump fixed durations only.
Widget _page() => AppShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                SkeletonCircle(),
                SizedBox(width: 8),
                Expanded(child: SkeletonBox()),
              ],
            ),
            SizedBox(height: 8),
            SkeletonBox(width: 120, height: 10, radius: 2),
            SizedBox(height: 8),
            SkeletonCard(),
            SizedBox(height: 8),
            // The shortest real card: customer detail's r(90) on a 320dp phone.
            SkeletonCard(height: 76),
            SizedBox(height: 8),
            SkeletonListTile(),
          ],
        ),
      ),
    );

void main() {
  setUpAll(initHarness);

  group('Skeleton layout', () {
    testOnEverySurface(
      'every skeleton shape renders in light and dark',
      (_) => SingleChildScrollView(child: _page()),
      verify: (tester, _) async {
        // Still animating, still clean, a few frames later.
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.byType(Shimmer), findsOneWidget);
      },
    );

    testOnEverySurface(
      'a full skeleton list clips to the viewport',
      (_) => const SkeletonList(),
      verify: (tester, s) async {
        final visible = find.byType(SkeletonListTile).evaluate().length;
        final fits = (s.size.height / SkeletonList.rowHeight).floor();
        expect(visible, inInclusiveRange(1, 8));
        expect(visible, greaterThanOrEqualTo(fits.clamp(1, 8)));
      },
    );
  });

  group('AppShimmer', () {
    for (final (surface, dark) in [(phoneEn, false), (surfaces[2], true)]) {
      testWidgets('uses the ${dark ? 'dark' : 'light'} shimmer pair',
          (tester) async {
        await pumpSurface(tester, surface, SingleChildScrollView(child: _page()));
        final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
        final (base, highlight) = AppColors.skeletonShimmer(dark);
        final colors = (shimmer.gradient as LinearGradient).colors;
        expect(colors.first, base);
        expect(colors, contains(highlight));
        expect(shimmer.period, AppDurations.shimmer);
      });
    }

    testWidgets('isolates its repaints behind a boundary', (tester) async {
      await pumpSurface(tester, phoneEn, SingleChildScrollView(child: _page()));
      expect(
        find.ancestor(
          of: find.byType(Shimmer),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      final boundary = find.descendant(
        of: find.byType(AppShimmer),
        matching: find.byType(RepaintBoundary),
      );
      expect(
        find.descendant(of: boundary.first, matching: find.byType(Shimmer)),
        findsOneWidget,
      );
    });

    testWidgets('keeps animating and disposes cleanly', (tester) async {
      await pumpSurface(tester, phoneEn, SingleChildScrollView(child: _page()));
      expect(tester.hasRunningAnimations, isTrue);
      await pumpSurface(tester, phoneEn, const SizedBox());
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('SkeletonBox and SkeletonCircle', () {
    testWidgets('box defaults: full width, 16 tall, small radius',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: SizedBox(width: 200, child: SkeletonBox())),
      );
      expect(tester.getSize(find.byType(SkeletonBox)), const Size(200, Insets.x4));
      final d = _decoration(tester, find.byType(SkeletonBox));
      expect(d.borderRadius, BorderRadius.circular(Radii.xs));
      expect(d.color, AppColors.onMap);
    });

    testWidgets('box honours width, height and radius', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: SkeletonBox(width: 50, height: 7, radius: 3)),
      );
      expect(tester.getSize(find.byType(SkeletonBox)), const Size(50, 7));
      expect(
        _decoration(tester, find.byType(SkeletonBox)).borderRadius,
        BorderRadius.circular(3),
      );
    });

    testWidgets('circle defaults to a chip-sized disc', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: SkeletonCircle()),
      );
      expect(
        tester.getSize(find.byType(SkeletonCircle)),
        const Size.square(CompSz.chip),
      );
      expect(_decoration(tester, find.byType(SkeletonCircle)).shape,
          BoxShape.circle);
    });

    testWidgets('circle honours its size, even zero', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonCircle(key: Key('big'), size: 72),
              SkeletonCircle(key: Key('none'), size: 0),
            ],
          ),
        ),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(find.byKey(const Key('big'))), const Size.square(72));
      expect(tester.getSize(find.byKey(const Key('none'))), Size.zero);
    });
  });

  group('SkeletonListTile and SkeletonList', () {
    for (final surface in [phoneEn, surfaces[0], surfaces[3]]) {
      testWidgets('a tile is exactly rowHeight tall — $surface',
          (tester) async {
        await pumpSurface(
          tester,
          surface,
          const Column(children: [SkeletonListTile()]),
        );
        expect(
          tester.getSize(find.byType(SkeletonListTile)).height,
          SkeletonList.rowHeight,
        );
        expect(find.byType(Divider), findsOneWidget);
      });
    }

    testWidgets('title and subtitle bars are shares of the row, not fixed',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        const Column(children: [SkeletonListTile()]),
      );
      expectCleanLayout(tester);
      final shares = [
        for (final e in find
            .descendant(
              of: find.byType(SkeletonListTile),
              matching: find.byType(FractionallySizedBox),
            )
            .evaluate())
          (e.widget as FractionallySizedBox).widthFactor,
      ];
      expect(shares, [0.55, 0.8]);
    });

    testWidgets('the avatar leads in the reading direction', (tester) async {
      Widget tile() => const Column(children: [SkeletonListTile()]);
      await pumpSurface(tester, phoneEn, tile());
      final enCircle = tester.getCenter(find.byType(SkeletonCircle)).dx;
      final enBar = tester.getCenter(find.byType(SkeletonBox).first).dx;
      expect(enCircle, lessThan(enBar));

      await pumpSurface(tester, phoneAr, tile());
      final arCircle = tester.getCenter(find.byType(SkeletonCircle)).dx;
      final arBar = tester.getCenter(find.byType(SkeletonBox).first).dx;
      expect(arCircle, greaterThan(arBar));
    });

    for (final count in const [0, 1, 3, 8]) {
      testWidgets('a list of $count rows lays them out on a fixed extent',
          (tester) async {
        await pumpSurface(tester, phoneEn, SkeletonList(itemCount: count));
        expect(find.byType(SkeletonListTile), findsNWidgets(count));
        expect(find.byType(Shimmer), findsOneWidget);
        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.itemExtent, SkeletonList.rowHeight);
        expect(list.physics, isA<NeverScrollableScrollPhysics>());
        if (count > 1) {
          final tops = [
            for (var i = 0; i < 2; i++)
              tester.getTopLeft(find.byType(SkeletonListTile).at(i)).dy,
          ];
          expect(tops[1] - tops[0], SkeletonList.rowHeight);
        }
      });
    }

    testWidgets('does not scroll under a drag', (tester) async {
      await pumpSurface(tester, phoneEn, const SkeletonList(itemCount: 40));
      final before = tester.getTopLeft(find.byType(SkeletonListTile).first);
      await tester.drag(find.byType(SkeletonList), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getTopLeft(find.byType(SkeletonListTile).first), before);
    });
  });

  group('SkeletonCard', () {
    testWidgets('default: 120 tall, card radius, three bars, no own shimmer',
        (tester) async {
      // In a ListView, like every real skeleton screen: full width.
      await pumpSurface(
        tester,
        phoneEn,
        ListView(
          padding: const EdgeInsets.all(16),
          children: const [SkeletonCard()],
        ),
      );
      final card = find.byType(SkeletonCard);
      expect(tester.getSize(card), const Size(358, 120));
      expect(_decoration(tester, card).borderRadius,
          BorderRadius.circular(Radii.lg));
      final bars = [
        for (final e in find
            .descendant(of: card, matching: find.byType(FractionallySizedBox))
            .evaluate())
          (e.widget as FractionallySizedBox).widthFactor,
      ];
      expect(bars, [0.6, 0.9, 0.4]);
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('side by side in a row, each card takes its share',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        const Row(
          children: [
            Expanded(child: SkeletonCard(key: Key('a'), height: 130)),
            SizedBox(width: 10),
            Expanded(child: SkeletonCard(key: Key('b'), height: 130)),
          ],
        ),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(find.byKey(const Key('a'))).width, 155);
      expect(tester.getSize(find.byKey(const Key('b'))).width, 155);
    });

    // Padding (16 × 2) plus the three bars (16 + 12 + 12) need 72dp; the
    // shortest real card is customer detail's r(90) = 76.5dp at 320dp.
    testWidgets('the shortest real card still fits its three bars',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[1],
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SkeletonCard(height: 76.5)],
        ),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(find.byType(SkeletonCard)).height, 76.5);
    });

    testWidgets('several cards share one shimmer', (tester) async {
      await pumpSurface(
        tester,
        surfaces[3],
        const AppShimmer(
          child: Column(
            children: [SkeletonCard(), SkeletonCard(), SkeletonCard()],
          ),
        ),
      );
      expectCleanLayout(tester);
      expect(find.byType(Shimmer), findsOneWidget);
    });
  });
}
