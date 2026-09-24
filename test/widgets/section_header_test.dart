import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/section_header.dart';

import 'widget_harness.dart';

/// A count badge like the dashboard's.
Widget _badge(String text) => Container(
      key: const Key('badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(text),
    );

void main() {
  setUpAll(initHarness);

  group('SectionHeader layout', () {
    testOnEverySurface(
      'every variant with long labels fits',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              label: LongText.of(s),
              icon: Icons.leaderboard,
              trailing: _badge('1,234'),
            ),
            SectionHeader(label: LongText.of(s), icon: Icons.map),
            SectionHeader(label: LongText.of(s), trailing: _badge('99+')),
            SectionHeader(label: 'W' * 150),
            const SectionHeader(label: ''),
            SectionHeader.eyebrow(
              label: LongText.of(s),
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            ),
            SectionHeader.eyebrow(label: 'W' * 150),
          ],
        ),
      ),
      verify: (tester, s) async {
        final label = tester.renderObject<RenderParagraph>(
          find.text(LongText.of(s)).first,
        );
        expect(label.didExceedMaxLines, isTrue);
      },
    );
  });

  group('SectionHeader (icon)', () {
    testWidgets('icon, label and trailing in reading order', (tester) async {
      Widget header() => SectionHeader(
            label: 'Top customers',
            icon: Icons.store,
            trailing: _badge('12'),
          );
      await pumpSurface(tester, phoneEn, header());
      final icon = tester.getCenter(find.byIcon(Icons.store)).dx;
      final label = tester.getCenter(find.text('Top customers')).dx;
      final badge = tester.getCenter(find.byKey(const Key('badge'))).dx;
      expect(icon < label && label < badge, isTrue);

      await pumpSurface(tester, phoneAr, header());
      final arIcon = tester.getCenter(find.byIcon(Icons.store)).dx;
      final arLabel = tester.getCenter(find.text('Top customers')).dx;
      final arBadge = tester.getCenter(find.byKey(const Key('badge'))).dx;
      expect(arIcon > arLabel && arLabel > arBadge, isTrue);
    });

    testWidgets('the trailing sits at the far end; the label fills the rest',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        SectionHeader(label: 'Short', trailing: _badge('3')),
      );
      final row = tester.getRect(find.byType(SectionHeader));
      final badge = tester.getRect(find.byKey(const Key('badge')));
      expect(badge.right, row.right);
      // Expanded, not Flexible: the label box runs up to the badge's gap.
      final label = tester.getRect(find.text('Short'));
      final context = tester.element(find.byType(SectionHeader));
      expect(
        label.right,
        moreOrLessEquals(badge.left - context.r(Insets.x2)),
      );
    });

    testWidgets('a long title is cut near the badge, not at half width',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        SectionHeader(
          label: LongText.arabicCompany,
          icon: Icons.leaderboard,
          trailing: _badge('27'),
        ),
      );
      expectCleanLayout(tester);
      final text = tester.widget<Text>(find.text(LongText.arabicCompany));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      final label = tester.getSize(find.text(LongText.arabicCompany)).width;
      expect(label, greaterThan(320 * 0.6));
    });

    testWidgets('without an icon or trailing the label starts at the edge',
        (tester) async {
      await pumpSurface(tester, phoneEn, const SectionHeader(label: 'Today'));
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.getTopLeft(find.text('Today')).dx,
        tester.getTopLeft(find.byType(SectionHeader)).dx,
      );
      expect(
        tester.getSize(find.text('Today')).width,
        tester.getSize(find.byType(SectionHeader)).width,
      );
    });

    for (final surface in [phoneEn, surfaces[2]]) {
      testWidgets('the icon is primary and the title is bold — $surface',
          (tester) async {
        await pumpSurface(
          tester,
          surface,
          const SectionHeader(label: 'Analytics', icon: Icons.insights),
        );
        final context = tester.element(find.byType(SectionHeader));
        final icon = tester.widget<Icon>(find.byIcon(Icons.insights));
        expect(icon.color, Theme.of(context).colorScheme.primary);
        expect(icon.size, context.r(IconSz.label));
        final title = tester.widget<Text>(find.text('Analytics'));
        expect(title.style?.fontWeight, FontWeight.w800);
        // Not upper-cased: only the eyebrow is.
        expect(find.text('ANALYTICS'), findsNothing);
      });
    }
  });

  group('SectionHeader.eyebrow', () {
    testWidgets('upper-cases, tracks and tints the label in en',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const SectionHeader.eyebrow(label: 'Contact details'),
      );
      expect(find.text('Contact details'), findsNothing);
      final text = tester.widget<Text>(find.text('CONTACT DETAILS'));
      final context = tester.element(find.byType(SectionHeader));
      expect(text.style?.color, Theme.of(context).colorScheme.primary);
      expect(text.style?.letterSpacing, 1.0);
      expect(text.style?.fontSize, AppType.eyebrow.fontSize);
      expect(find.byType(Icon), findsNothing);
    });

    for (final surface in [phoneAr, surfaces[2]]) {
      testWidgets('keeps Arabic letters joined (no tracking) — $surface',
          (tester) async {
        final label = l10n(surface.locale).wfTypeProject;
        await pumpSurface(
          tester,
          surface,
          SectionHeader.eyebrow(label: label),
        );
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.letterSpacing, 0);
        final context = tester.element(find.byType(SectionHeader));
        expect(text.style?.color, Theme.of(context).colorScheme.primary);
      });
    }

    testWidgets('applies its padding, mirrored in RTL', (tester) async {
      const padding = EdgeInsetsDirectional.only(start: 20, top: 6);
      Widget eyebrow() => const Align(
            alignment: AlignmentDirectional.topStart,
            child: SectionHeader.eyebrow(label: 'x', padding: padding),
          );
      await pumpSurface(tester, phoneEn, eyebrow());
      final en = tester.getTopLeft(find.text('X')) -
          tester.getTopLeft(find.byType(SectionHeader));
      expect(en, const Offset(20, 6));

      await pumpSurface(tester, phoneAr, eyebrow());
      final header = tester.getRect(find.byType(SectionHeader));
      final text = tester.getRect(find.text('X'));
      expect(header.right - text.right, 20);
      expect(text.top - header.top, 6);
    });

    testWidgets('a long eyebrow wraps instead of overflowing', (tester) async {
      await pumpSurface(
        tester,
        surfaces[1],
        const SectionHeader.eyebrow(
          label: 'Notification and location permissions for this device',
        ),
      );
      expectCleanLayout(tester);
      final size = tester.getSize(find.textContaining('NOTIFICATION'));
      expect(size.height, greaterThan(AppType.eyebrow.fontSize! * 1.25 * 1.5));
    });
  });
}
