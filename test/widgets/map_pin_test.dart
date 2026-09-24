import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/initial_avatar.dart';
import 'package:location_gps/shared/widgets/map_pin.dart';

import 'widget_harness.dart';

const _brand = LinearGradient(colors: [Color(0xFF1B2A6B), Color(0xFF3AA6B9)]);

BoxDecoration _decoration(WidgetTester tester, Finder pin) => tester
    .widget<Container>(
        find.descendant(of: pin, matching: find.byType(Container)).first)
    .decoration! as BoxDecoration;

/// [text] is laid out at its natural size (not wrapped or clipped) and
/// painted within the pin that holds it.
void _expectWholeInsideDisc(WidgetTester tester, String text) {
  final p = tester.renderObject<RenderParagraph>(find.text(text));
  expect(p.size.width,
      greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.01));
  expect(p.size.height,
      lessThanOrEqualTo(p.getMinIntrinsicHeight(double.infinity) + 0.01));
  final disc = tester
      .getRect(find.ancestor(of: find.text(text), matching: find.byType(MapPin)))
      .inflate(0.01);
  final rect = tester.getRect(find.text(text));
  expect(disc.contains(rect.topLeft) && disc.contains(rect.bottomRight), isTrue,
      reason: '"$text" at $rect, disc $disc');
}

void main() {
  setUpAll(initHarness);

  testOnEverySurface(
    'every pin kind over a map strip fits',
    (s) => Container(
      color: AppColors.mapBackground(s.brightness == Brightness.dark),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          MapPin.icon(icon: Icons.storefront_rounded, color: AppColors.ink),
          MapPin.icon(
            icon: Icons.flag_rounded,
            gradient: _brand,
            size: CompSz.mapPin,
            borderWidth: CompSz.mapPinRing,
          ),
          // A person pin: the initial of a long Arabic name, the full name
          // left to the tooltip.
          MapPin.label(
            text: InitialAvatar.initialOf(LongText.arabicPerson),
            color: AppColors.green,
            size: 38,
            tooltip: LongText.arabicPerson,
          ),
          // Route stop numbers, as the route map draws them.
          for (final n in const ['1', '9', '12'])
            MapPin.label(
              text: n,
              size: 32,
              borderWidth: 2,
              color: AppColors.ink,
            ),
          const MapPin(
            size: 24,
            borderWidth: 1,
            color: Colors.orange,
            child: SizedBox.shrink(),
          ),
        ],
      ),
    ),
    verify: (tester, _) async {
      expect(find.byType(MapPin), findsNWidgets(7));
      // Stop numbers are drawn whole, on one line, inside the disc — even
      // at the 1.25x text scale, which the fixed-size disc doesn't follow.
      for (final n in const ['1', '9', '12']) {
        _expectWholeInsideDisc(tester, n);
      }
    },
  );

  group('MapPin shape', () {
    testWidgets('a circle of the given size with a white ring and a shadow',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: MapPin.icon(
            key: const Key('pin'),
            icon: Icons.place,
            color: AppColors.ink,
          ),
        ),
      );
      final pin = find.byKey(const Key('pin'));
      expect(tester.getSize(pin), const Size.square(42));
      final d = _decoration(tester, pin);
      expect(d.shape, BoxShape.circle);
      expect(d.color, AppColors.ink);
      expect(d.gradient, isNull);
      final ring = (d.border! as Border).top;
      expect(ring.color, Colors.white);
      expect(ring.width, 2.5);
      expect(d.boxShadow, hasLength(1));
      expect(d.boxShadow!.single.blurRadius, greaterThan(0));
      expect(d.boxShadow!.single.offset.dy, greaterThan(0));
    });

    testWidgets('every pin shares one ring and shadow weight', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MapPin.icon(key: const Key('a'), icon: Icons.place, color: Colors.red),
            MapPin.label(key: const Key('b'), text: 'A', color: Colors.blue),
          ],
        ),
      );
      final a = _decoration(tester, find.byKey(const Key('a')));
      final b = _decoration(tester, find.byKey(const Key('b')));
      expect(a.boxShadow, b.boxShadow);
      expect(a.border, b.border);
    });

    testWidgets('a gradient replaces the flat fill', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: MapPin.label(
            key: const Key('pin'),
            text: '3',
            color: Colors.red,
            gradient: _brand,
          ),
        ),
      );
      final d = _decoration(tester, find.byKey(const Key('pin')));
      expect(d.gradient, _brand);
      expect(d.color, isNull);
    });

    testWidgets('size, ring width and ring colour are honoured',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: MapPin(
            key: Key('pin'),
            size: 30,
            borderWidth: 4,
            borderColor: Colors.black,
            color: Colors.yellow,
            child: Text('x'),
          ),
        ),
      );
      final pin = find.byKey(const Key('pin'));
      expect(tester.getSize(pin), const Size.square(30));
      final ring = (_decoration(tester, pin).border! as Border).top;
      expect(ring.width, 4);
      expect(ring.color, Colors.black);
    });

    testWidgets('the content is centred in the disc', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        Center(
          child: MapPin.label(
            key: const Key('pin'),
            text: '7',
            color: AppColors.ink,
          ),
        ),
      );
      expect(
        tester.getCenter(find.text('7')),
        tester.getCenter(find.byKey(const Key('pin'))),
      );
    });
  });

  group('MapPin content', () {
    for (final size in const [24.0, 42.0, 64.0]) {
      testWidgets('icon and label scale with a ${size}dp pin', (tester) async {
        await pumpSurface(
          tester,
          phoneEn,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapPin.icon(icon: Icons.place, color: Colors.red, size: size),
              MapPin.label(text: 'M', color: Colors.red, size: size),
            ],
          ),
        );
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, size * 0.45);
        expect(icon.color, Colors.white);
        final label = tester.widget<Text>(find.text('M'));
        expect(label.style?.fontSize, size * 0.36);
        expect(label.style?.fontWeight, FontWeight.w800);
        expect(label.style?.color, Colors.white);
        expectCleanLayout(tester);
      });
    }

    for (final surface in [surfaces[0], surfaces[3]]) {
      testWidgets('a 3-digit stop number stays whole in a 32dp pin — $surface',
          (tester) async {
        await pumpSurface(
          tester,
          surface,
          Center(
            child: MapPin.label(
              text: '128',
              size: 32,
              borderWidth: 2,
              color: AppColors.ink,
            ),
          ),
        );
        expectCleanLayout(tester);
        _expectWholeInsideDisc(tester, '128');
      });
    }

    testWidgets('icon and text colours can be overridden', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MapPin.icon(
              icon: Icons.place,
              color: Colors.white,
              iconColor: AppColors.ink,
            ),
            MapPin.label(
              text: 'Q',
              color: Colors.white,
              textColor: AppColors.ink,
            ),
          ],
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, AppColors.ink);
      expect(tester.widget<Text>(find.text('Q')).style?.color, AppColors.ink);
    });
  });

  group('MapPin tooltip', () {
    testWidgets('no tooltip unless asked for', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Center(child: MapPin.label(text: 'S', color: Colors.green)),
      );
      expect(find.byType(Tooltip), findsNothing);
    });

    for (final surface in [phoneEn, phoneAr]) {
      testWidgets('long-press reveals the full name — $surface',
          (tester) async {
        final name =
            surface.isArabic ? LongText.arabicPerson : 'Sara Al-Qahtani';
        await pumpSurface(
          tester,
          surface,
          Center(
            child: MapPin.label(
              key: const Key('pin'),
              text: InitialAvatar.initialOf(name),
              color: Colors.green,
              tooltip: name,
            ),
          ),
        );
        expect(find.text(name), findsNothing);
        await tester.longPress(find.byKey(const Key('pin')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(name), findsOneWidget);
        expectCleanLayout(tester);
        // Let the tooltip's dismiss timer run out before teardown.
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('the tooltip gives a screen reader the name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        Center(
          child: MapPin.icon(
            icon: Icons.person_pin,
            color: Colors.green,
            tooltip: 'Sara Al-Qahtani',
          ),
        ),
      );
      expect(find.byTooltip('Sara Al-Qahtani'), findsOneWidget);
      expect(
        find.semantics.byPredicate((n) => n.tooltip == 'Sara Al-Qahtani'),
        findsOne,
      );
      handle.dispose();
    });
  });
}
