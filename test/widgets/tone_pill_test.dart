import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/tone_pill.dart';

import 'widget_harness.dart';

const _green = Color(0xFF1E8E3E);

/// A card header: a title that takes the rest of the row and a chip that the
/// row has to squeeze — the case `flexibleLabel` exists for.
Widget _header(Surface s, {required String label, String? title}) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title ?? LongText.of(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: TonePill(
              key: const Key('pill'),
              label: label,
              color: _green,
              icon: Icons.fiber_manual_record,
              flexibleLabel: true,
            ),
          ),
        ],
      ),
    );

void main() {
  setUpAll(initHarness);

  group('TonePill layout', () {
    testOnEverySurface(
      'a flexible pill with a long label is squeezed by a header row',
      (s) => _header(s, label: '${LongText.of(s)} ${LongText.of(s)}'),
      verify: (tester, s) async {
        final label = tester.renderObject<RenderParagraph>(
          find.text('${LongText.of(s)} ${LongText.of(s)}'),
        );
        expect(label.didExceedMaxLines, isTrue);
        final pill = tester.getRect(find.byKey(const Key('pill')));
        expect(pill.width, lessThan(tester.view.physicalSize.width));
      },
    );

    testOnEverySurface(
      'a very long single word ellipsizes in a flexible pill',
      (s) => _header(s, label: 'A' * 200, title: 'T'),
    );

    testOnEverySurface(
      'natural-width pills sit in plain rows and wraps',
      (s) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A list row: the pill in a Row with no bound on its width.
            Row(
              children: [
                TonePill(
                  label: l10n(s.locale).wfEscalatedBadge,
                  color: Colors.red,
                  icon: Icons.priority_high_rounded,
                  borderAlpha: Alphas.border,
                  radius: Radii.xs,
                ),
                const SizedBox(width: 8),
                TonePill(label: '12', color: _green),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in [
                  l10n(s.locale).wfTypeProject,
                  l10n(s.locale).wfTypeOpportunity,
                  l10n(s.locale).trailLive,
                ])
                  TonePill(label: label, color: _green, icon: Icons.label),
              ],
            ),
            const SizedBox(height: 8),
            // Text-only pill bounded by its parent: ellipsizes.
            SizedBox(
              width: 120,
              child: TonePill(label: LongText.of(s), color: _green),
            ),
          ],
        ),
      ),
    );
  });

  group('TonePill flexibleLabel', () {
    testWidgets('off by default: the label is a bare Row child',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Row(
          children: [
            TonePill(label: 'Live', color: _green, icon: Icons.circle),
          ],
        ),
      );
      expectCleanLayout(tester);
      expect(
        find.descendant(
          of: find.byType(TonePill),
          matching: find.byType(Flexible),
        ),
        findsNothing,
      );
      // Natural width: the label is not squeezed.
      final label = tester.renderObject<RenderParagraph>(find.text('Live'));
      expect(label.didExceedMaxLines, isFalse);
    });

    testWidgets('on: the label gives way inside a bounded row',
        (tester) async {
      await pumpSurface(
        tester,
        surfaces[0],
        _header(surfaces[0], label: LongText.arabicCompany, title: 'T'),
      );
      expectCleanLayout(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('pill')),
          matching: find.byType(Flexible),
        ),
        findsOneWidget,
      );
      // The icon stays whole beside the ellipsized label.
      final icon = tester.getSize(find.byIcon(Icons.fiber_manual_record));
      expect(icon.width, IconSz.pill);
      final pill = tester.getRect(find.byKey(const Key('pill')));
      final title = tester.getRect(find.text('T'));
      expect(pill.right, lessThanOrEqualTo(title.left)); // RTL
    });

    testWidgets('on: a short label keeps its natural width', (tester) async {
      await pumpSurface(tester, phoneEn, _header(phoneEn, label: 'Live'));
      final label = tester.renderObject<RenderParagraph>(find.text('Live'));
      expect(label.didExceedMaxLines, isFalse);
      final pill = tester.getSize(find.byKey(const Key('pill')));
      expect(pill.width, lessThan(120));
    });
  });

  group('TonePill appearance', () {
    BoxDecoration decoration(WidgetTester tester) => tester
        .widget<Container>(find.descendant(
          of: find.byType(TonePill),
          matching: find.byType(Container),
        ))
        .decoration! as BoxDecoration;

    testWidgets('defaults: tinted pill, no border, bold small text',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: TonePill(label: 'Approved', color: _green)),
      );
      final d = decoration(tester);
      expect(d.color, _green.withValues(alpha: Alphas.tint));
      expect(d.border, isNull);
      expect(d.borderRadius, BorderRadius.circular(Radii.pill));
      final text = tester.widget<Text>(find.text('Approved'));
      expect(text.style?.color, _green);
      expect(text.style?.fontSize, FontSz.sm);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('every knob is honoured', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: TonePill(
            label: '3',
            color: Colors.white,
            icon: Icons.cloud_upload,
            foreground: AppColors.ink,
            fontSize: FontSz.xs,
            iconSize: IconSz.inline,
            tintAlpha: Alphas.wash,
            borderAlpha: Alphas.border,
            fontWeight: FontWeight.w500,
            radius: Radii.xs,
            padding: EdgeInsets.all(3),
          ),
        ),
      );
      final d = decoration(tester);
      expect(d.color, Colors.white.withValues(alpha: Alphas.wash));
      expect(d.borderRadius, BorderRadius.circular(Radii.xs));
      expect(
        (d.border! as Border).top.color,
        Colors.white.withValues(alpha: Alphas.border),
      );
      final text = tester.widget<Text>(find.text('3'));
      expect(text.style?.color, AppColors.ink);
      expect(text.style?.fontSize, FontSz.xs);
      expect(text.style?.fontWeight, FontWeight.w500);
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_upload));
      expect(icon.color, AppColors.ink);
      expect(icon.size, IconSz.inline);
      expect(icon.fill, 1);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(TonePill),
        matching: find.byType(Container),
      ));
      expect(container.padding, const EdgeInsets.all(3));
    });

    testWidgets('the icon leads in the reading direction', (tester) async {
      Widget pill() => const Center(
            child: TonePill(label: 'Live', color: _green, icon: Icons.circle),
          );
      await pumpSurface(tester, phoneEn, pill());
      expect(
        tester.getCenter(find.byIcon(Icons.circle)).dx,
        lessThan(tester.getCenter(find.text('Live')).dx),
      );
      await pumpSurface(tester, phoneAr, pill());
      expect(
        tester.getCenter(find.byIcon(Icons.circle)).dx,
        greaterThan(tester.getCenter(find.text('Live')).dx),
      );
    });

    testWidgets('an empty label still renders a pill', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(
          child: TonePill(label: '', color: _green, icon: Icons.circle),
        ),
      );
      expectCleanLayout(tester);
      expect(tester.getSize(find.byType(TonePill)).width, greaterThan(0));
    });
  });
}
