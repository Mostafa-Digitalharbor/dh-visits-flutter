import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/app_card.dart';

import 'widget_harness.dart';

const _child = Key('card-child');

/// A realistic card body: glyph, a long company name and a person's name.
Widget _body(Surface s) => Row(
  children: [
    const Icon(Icons.store_mall_directory_outlined),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LongText.of(s), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(LongText.arabicPerson),
        ],
      ),
    ),
    const Icon(Icons.chevron_right),
  ],
);

Finder get _ink =>
    find.descendant(of: find.byType(AppCard), matching: find.byType(InkWell));

Finder get _scaleFinder => find.descendant(
  of: find.byType(AppCard),
  matching: find.byType(ScaleTransition),
);

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(_scaleFinder).scale.value;

Material _material(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: find.byType(Card), matching: find.byType(Material)).first,
);

/// The ink layer the card's InkWell paints its ripple on.
RenderObject _inkLayer(WidgetTester tester) =>
    Material.of(tester.element(_ink)) as RenderObject;

void main() {
  setUpAll(initHarness);

  group('AppCard layout', () {
    for (final tappable in [true, false]) {
      testOnEverySurface(
        '${tappable ? 'tappable' : 'static'} card with long text fits',
        (s) => Padding(
          padding: const EdgeInsets.all(16),
          child: AppCard(onTap: tappable ? () {} : null, child: _body(s)),
        ),
      );
    }

    testOnEverySurface(
      'a stack of cards with custom padding and colour scrolls',
      (s) => Column(
        children: [
          for (var i = 0; i < 8; i++)
            AppCard(
              padding: i.isEven
                  ? EdgeInsets.zero
                  : const EdgeInsetsDirectional.fromSTEB(40, 8, 4, 8),
              color: i == 3 ? Colors.amber : null,
              onTap: i.isEven ? () {} : null,
              child: _body(s),
            ),
        ],
      ),
      scrollable: true,
      verify: (tester, s) async {
        expect(find.byType(AppCard), findsNWidgets(8));
      },
    );
  });

  group('AppCard behaviour', () {
    testWidgets('fires onTap once per tap', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        AppCard(onTap: () => taps++, child: const Text('Open')),
      );
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 2);
    });

    testWidgets('a static card has no press animation and taps are harmless', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, const AppCard(child: Text('Info')));
      expect(_scaleFinder, findsNothing);
      expect(tester.widget<InkWell>(_ink).onTap, isNull);
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a static card shows no ripple when pressed', (tester) async {
      await pumpSurface(tester, phoneEn, const AppCard(child: Text('Info')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // A ripple on a card that does nothing tells the user it is a button.
      expect(_inkLayer(tester), isNot(paints..circle()));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a tappable card does ripple when pressed', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppCard(onTap: () {}, child: const Text('Open')),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_inkLayer(tester), paints..circle());
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a static card is neither clickable nor focusable', (
      tester,
    ) async {
      Future<(MouseCursor, bool)> probe(VoidCallback? onTap) async {
        await pumpSurface(
          tester,
          phoneEn,
          AppCard(onTap: onTap, child: const Text('x')),
        );
        final region = tester.widget<MouseRegion>(
          find.descendant(of: _ink, matching: find.byType(MouseRegion)).first,
        );
        final focus = tester.widget<Focus>(
          find.descendant(of: _ink, matching: find.byType(Focus)).first,
        );
        return (region.cursor, focus.canRequestFocus);
      }

      final (staticCursor, staticFocus) = await probe(null);
      expect(staticCursor, SystemMouseCursors.basic);
      expect(staticFocus, isFalse);

      final (tapCursor, tapFocus) = await probe(() {});
      expect(tapCursor, SystemMouseCursors.click);
      expect(tapFocus, isTrue);
    });

    testWidgets('press takes the fast duration down to 96%', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppCard(onTap: () {}, child: const Text('Open')),
      );
      expect(_scale(tester), 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pump(); // first tick of the press
      await tester.pump(AppDurations.fast);
      expect(_scale(tester), closeTo(0.96, 1e-9));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
    });

    testWidgets('release settles back over the slower cardRelease duration', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        AppCard(onTap: () {}, child: const Text('Open')),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pumpAndSettle();
      expect(_scale(tester), closeTo(0.96, 1e-9));

      await gesture.up();
      await tester.pump(); // first tick of the release
      await tester.pump(AppDurations.fast);
      expect(
        _scale(tester),
        lessThan(1),
        reason: 'the release snapped back as fast as the press',
      );
      await tester.pump(AppDurations.cardRelease - AppDurations.fast);
      expect(_scale(tester), 1);
      expect(AppDurations.cardRelease, greaterThan(AppDurations.fast));
    });

    testWidgets('dragging off the card cancels: no tap, scale restored', (
      tester,
    ) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        Align(
          alignment: Alignment.topCenter,
          child: AppCard(onTap: () => taps++, child: const Text('Open')),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pumpAndSettle();
      expect(_scale(tester), lessThan(1));
      await gesture.moveBy(const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('onTap can be added and removed at runtime', (tester) async {
      var taps = 0;
      Widget card(VoidCallback? onTap) =>
          AppCard(onTap: onTap, child: const Text('Open'));

      await pumpSurface(tester, phoneEn, card(null));
      await tester.tap(find.byType(AppCard));
      expect(taps, 0);

      await pumpSurface(tester, phoneEn, card(() => taps++));
      expect(_scaleFinder, findsOneWidget);
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);

      // Removed mid-press: the animation goes with it, nothing throws.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppCard)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await pumpSurface(tester, phoneEn, card(null));
      expect(_scaleFinder, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);

      // Disposing both kinds of card is clean — the controller is never
      // created during teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a static card that is disposed never built a controller', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, const AppCard(child: Text('Info')));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('default padding is Insets.cardPad on every side', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: AppCard(child: SizedBox(key: _child, width: 50, height: 20)),
        ),
      );
      final card = tester.getRect(find.byType(Card));
      final child = tester.getRect(find.byKey(_child));
      expect(child.left - card.left, Insets.cardPad);
      expect(child.top - card.top, Insets.cardPad);
      expect(card.right - child.right, Insets.cardPad);
      expect(card.bottom - child.bottom, Insets.cardPad);
    });

    testWidgets('directional padding mirrors in Arabic', (tester) async {
      Future<(double, double)> gaps(Surface s) async {
        await pumpSurface(
          tester,
          s,
          const AppCard(
            padding: EdgeInsetsDirectional.only(start: 40, end: 4),
            child: SizedBox(key: _child, height: 20),
          ),
        );
        final card = tester.getRect(find.byType(Card));
        final child = tester.getRect(find.byKey(_child));
        return (child.left - card.left, card.right - child.right);
      }

      expect(await gaps(phoneEn), (40.0, 4.0));
      expect(await gaps(phoneAr), (4.0, 40.0));
    });

    testWidgets('a one-line tappable card is at least a 48dp target and '
        'exposes a tap action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        Align(
          alignment: Alignment.topCenter,
          child: AppCard(onTap: () {}, child: const Text('Open')),
        ),
      );
      expect(
        tester.getSize(find.byType(AppCard)).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      expect(
        tester.getSemantics(find.text('Open')),
        containsSemantics(label: 'Open', hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('a static card exposes no tap action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSurface(tester, phoneEn, const AppCard(child: Text('Info')));
      expect(
        tester.getSemantics(find.text('Info')),
        containsSemantics(label: 'Info', hasTapAction: false),
      );
      semantics.dispose();
    });
  });

  group('AppCard theming', () {
    for (final s in [phoneEn, surfaces[2]]) {
      testWidgets('the default fill is the theme card colour — $s', (
        tester,
      ) async {
        await pumpSurface(tester, s, const AppCard(child: Text('x')));
        final theme = Theme.of(tester.element(find.byType(Card)));
        expect(theme.brightness, s.brightness);
        expect(_material(tester).color, theme.cardTheme.color);
        expect(
          _material(tester).color,
          theme.colorScheme.surfaceContainerLowest,
        );
      });
    }

    testWidgets('an explicit colour overrides the theme', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AppCard(color: Colors.teal, child: Text('x')),
      );
      expect(_material(tester).color, Colors.teal);
    });

    testWidgets('clips its content and ink to the rounded shape', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, const AppCard(child: Text('x')));
      expect(
        tester.widget<Card>(find.byType(Card)).clipBehavior,
        Clip.antiAlias,
      );
    });
  });
}
