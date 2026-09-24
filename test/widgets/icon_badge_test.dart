import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/extensions/context_extensions.dart';
import 'package:location_gps/shared/widgets/icon_badge.dart';

import 'widget_harness.dart';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

Finder get _badge => find.byType(IconBadge);

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(
      find.descendant(of: _badge, matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration;

Icon _icon(WidgetTester tester) =>
    tester.widget<Icon>(find.descendant(of: _badge, matching: find.byType(Icon)));

/// A badge the way list rows use it: leading a line of text.
Widget _row(Widget badge, String text) => Row(
      children: [
        badge,
        const SizedBox(width: Insets.x3),
        Expanded(child: Text(text)),
      ],
    );

void main() {
  setUpAll(initHarness);

  group('IconBadge layout', () {
    testOnEverySurface(
      'leading a long wrapping row',
      (s) => Builder(
        builder: (context) => Column(
          children: [
            _row(
              IconBadge(
                  icon: Icons.business, color: context.colors.primary),
              '${LongText.of(s)} ${LongText.of(s)}',
            ),
            _row(
              IconBadge(
                icon: Icons.analytics_outlined,
                color: context.x.success,
                size: CompSz.badgeLg,
                iconSize: IconSz.md,
              ),
              LongText.of(s),
            ),
            _row(
              IconBadge(
                icon: Icons.map_outlined,
                color: context.colors.tertiary,
                padding: const EdgeInsets.all(Insets.x2),
              ),
              LongText.of(s),
            ),
          ],
        ),
      ),
      scrollable: true,
      verify: (tester, s) async {
        // Fixed badges never shrink next to long text.
        expect(tester.getSize(_badge.at(0)),
            const Size(CompSz.badge, CompSz.badge));
        expect(tester.getSize(_badge.at(1)),
            const Size(CompSz.badgeLg, CompSz.badgeLg));
        // A padded badge hugs its glyph: the default 19dp + 8dp a side.
        expect(tester.getSize(_badge.at(2)), const Size(35, 35));
      },
    );
  });

  group('IconBadge defaults', () {
    testWidgets('a 36dp rounded square with a 12% tint and a 19dp glyph',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(const IconBadge(icon: Icons.person, color: Colors.teal), 't'),
      );
      expect(tester.getSize(_badge), const Size(CompSz.badge, CompSz.badge));
      final d = _decoration(tester);
      expect(d.color, Colors.teal.withValues(alpha: Alphas.tint));
      expect(d.borderRadius, BorderRadius.circular(Radii.tile));
      final icon = _icon(tester);
      expect(icon.icon, Icons.person);
      expect(icon.size, 19);
      expect(icon.color, Colors.teal);
      expect(icon.fill, isNull);
      // The glyph is centred in the square.
      expect(tester.getCenter(find.byType(Icon)),
          offsetMoreOrLessEquals(tester.getCenter(_badge)));
    });

    testWidgets('does not scale with the device or the text size',
        (tester) async {
      // The badge is a fixed design size; callers scale it if they need to.
      await pumpSurface(
        tester,
        surfaces.first, // 320dp · 1.25×
        _row(const IconBadge(icon: Icons.person, color: Colors.teal), 't'),
      );
      expect(tester.getSize(_badge), const Size(CompSz.badge, CompSz.badge));
      expect(_icon(tester).size, 19);
    });

    testWidgets('is decorative: no semantics of its own', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: IconBadge(icon: Icons.person, color: Colors.teal)),
      );
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });
  });

  group('IconBadge options', () {
    testWidgets('size, iconSize, radius and tintAlpha are honoured',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(
          const IconBadge(
            icon: Icons.star,
            color: Colors.orange,
            size: 50,
            iconSize: 30,
            radius: Radii.sm,
            tintAlpha: 0.3,
          ),
          't',
        ),
      );
      expect(tester.getSize(_badge), const Size(50, 50));
      expect(_icon(tester).size, 30);
      final d = _decoration(tester);
      expect(d.borderRadius, BorderRadius.circular(Radii.sm));
      expect(d.color, Colors.orange.withValues(alpha: 0.3));
    });

    testWidgets('iconColor overrides only the glyph', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(
          const IconBadge(
            icon: Icons.star,
            color: Colors.white,
            iconColor: AppColors.cyan400,
            tintAlpha: Alphas.wash,
          ),
          't',
        ),
      );
      expect(_icon(tester).color, AppColors.cyan400);
      expect(_decoration(tester).color,
          Colors.white.withValues(alpha: Alphas.wash));
    });

    testWidgets('background replaces the tint outright', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        Builder(
          builder: (context) => _row(
            IconBadge(
              icon: Icons.people,
              color: context.colors.onPrimaryContainer,
              background: context.colors.primaryContainer,
            ),
            't',
          ),
        ),
      );
      final cs = Theme.of(tester.element(_badge)).colorScheme;
      expect(_decoration(tester).color, cs.primaryContainer);
      expect(_icon(tester).color, cs.onPrimaryContainer);
    });

    testWidgets('padding makes the badge hug its glyph, even in a row with '
        'room to grow', (tester) async {
      // Regression: the Container's alignment made a padded badge fill the
      // row's whole height (36×844 here).
      await pumpSurface(
        tester,
        phoneEn,
        _row(
          const IconBadge(
            icon: Icons.map,
            color: Colors.blue,
            iconSize: 20,
            padding: EdgeInsets.all(Insets.x2),
          ),
          't',
        ),
      );
      // 20dp glyph + 8dp on each side; the default 36dp size is ignored.
      expect(tester.getCenter(find.byType(Icon)),
          offsetMoreOrLessEquals(tester.getCenter(_badge)));
      expect(tester.getSize(_badge), const Size(36, 36));
      await pumpSurface(
        tester,
        phoneEn,
        _row(
          const IconBadge(
            icon: Icons.map,
            color: Colors.blue,
            iconSize: 20,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          't',
        ),
      );
      expect(tester.getSize(_badge), const Size(44, 28));
    });

    testWidgets('a sized badge in a tall row stays square', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Row(children: [IconBadge(icon: Icons.map, color: Colors.blue)]),
      );
      expect(tester.getSize(_badge), const Size(CompSz.badge, CompSz.badge));
    });

    testWidgets('fill is passed to the glyph', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(const IconBadge(icon: Icons.star, color: Colors.red, fill: 1), 't'),
      );
      expect(_icon(tester).fill, 1);
    });

    testWidgets('a zero tint leaves the square transparent', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(
          const IconBadge(icon: Icons.star, color: Colors.red, tintAlpha: 0),
          't',
        ),
      );
      expect(_decoration(tester).color!.a, 0);
      expect(_icon(tester).color, Colors.red);
    });
  });

  group('IconBadge theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('a theme colour tints it in both brightnesses — $s',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          Builder(
            builder: (context) => _row(
              IconBadge(icon: Icons.check, color: context.x.success),
              't',
            ),
          ),
        );
        final context = tester.element(_badge);
        expect(Theme.of(context).brightness, s.brightness);
        expect(_icon(tester).color, context.x.success);
        expect(_decoration(tester).color,
            context.x.success.withValues(alpha: Alphas.tint));
      });
    }

    testWidgets('it sits at the reading start in both directions',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _row(const IconBadge(icon: Icons.star, color: Colors.red), 'text'),
      );
      final enBadge = tester.getCenter(_badge).dx;
      final enText = tester.getCenter(find.text('text')).dx;
      await pumpSurface(
        tester,
        phoneAr,
        _row(const IconBadge(icon: Icons.star, color: Colors.red), 'text'),
      );
      final arBadge = tester.getCenter(_badge).dx;
      final arText = tester.getCenter(find.text('text')).dx;
      expect(enBadge, lessThan(enText));
      expect(arBadge, greaterThan(arText));
    });
  });
}
