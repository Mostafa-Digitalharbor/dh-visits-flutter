import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/status_banner.dart';

import 'widget_harness.dart';

const _amber = Color(0xFFB26A00);

/// A short action label, as the real banners use ("Retry", "Settings").
/// The test font draws every glyph 1em wide, which makes the Arabic "Retry"
/// about 2.5× its real width — too wide to stand in for a real label.
Widget _banner(Surface s, {VoidCallback? onAction, String? message}) {
  final t = l10n(s.locale);
  return Column(
    children: [
      StatusBanner(
        color: _amber,
        icon: Icons.cloud_off_rounded,
        message: message ?? t.offlineNoQueue,
        action: onAction == null
            ? null
            : TextButton(onPressed: onAction, child: Text(t.commonClose)),
      ),
    ],
  );
}

void main() {
  setUpAll(initHarness);

  group('StatusBanner layout', () {
    testOnEverySurface(
      'a long message with an action fits and wraps',
      (s) => _banner(s, onAction: () {}, message: LongText.of(s)),
      verify: (tester, s) async {
        final banner = tester.getRect(find.byType(StatusBanner));
        final action = tester.getRect(find.byType(TextButton));
        expect(banner.contains(action.center), isTrue);
        // Wrapped rather than cut: more than one line tall.
        final text = tester.getSize(find.text(LongText.of(s)));
        expect(text.height, greaterThan(FontSz.sm * 2));
      },
    );

    testOnEverySurface(
      'a stack of two banners (offline + syncing) fits',
      (s) => Column(
        children: [
          StatusBanner(
            color: Colors.red,
            icon: Icons.cloud_off_rounded,
            message: l10n(s.locale).offlineWithQueue(12),
          ),
          StatusBanner(
            color: _amber,
            icon: Icons.sync_rounded,
            message: l10n(s.locale).offlineSyncing(12),
            action: IconButton(
              onPressed: () {},
              tooltip: l10n(s.locale).commonClose,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  });

  group('StatusBanner behaviour', () {
    testWidgets('the action fires once per tap', (tester) async {
      var taps = 0;
      await pumpSurface(tester, phoneEn, _banner(phoneEn, onAction: () => taps++));
      await tester.tap(find.text(l10n(english).commonClose));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('without an action the message runs to the end edge',
        (tester) async {
      await pumpSurface(tester, phoneEn, _banner(phoneEn));
      expect(find.byType(TextButton), findsNothing);
      final banner = tester.getRect(find.byType(StatusBanner));
      final text = tester.getRect(find.text(l10n(english).offlineNoQueue));
      final context = tester.element(find.byType(StatusBanner));
      expect(
        text.right,
        moreOrLessEquals(banner.right - context.r(Insets.x3)),
      );
    });

    testWidgets('with an action the message stops before it', (tester) async {
      await pumpSurface(tester, phoneEn, _banner(phoneEn, onAction: () {}));
      final text = tester.getRect(find.text(l10n(english).offlineNoQueue));
      final action = tester.getRect(find.byType(TextButton));
      expect(text.right, lessThanOrEqualTo(action.left));
    });

    testWidgets('spans the full width', (tester) async {
      await pumpSurface(tester, phoneEn, _banner(phoneEn));
      expect(tester.getSize(find.byType(StatusBanner)).width, 390);
    });

    testWidgets('icon at the start, action at the end — mirrored in ar',
        (tester) async {
      await pumpSurface(tester, phoneEn, _banner(phoneEn, onAction: () {}));
      final enIcon = tester.getCenter(find.byIcon(Icons.cloud_off_rounded));
      final enAction = tester.getCenter(find.byType(TextButton));
      expect(enIcon.dx, lessThan(enAction.dx));

      await pumpSurface(tester, phoneAr, _banner(phoneAr, onAction: () {}));
      final arIcon = tester.getCenter(find.byIcon(Icons.cloud_off_rounded));
      final arAction = tester.getCenter(find.byType(TextButton));
      expect(arIcon.dx, greaterThan(arAction.dx));
      expect(find.text(l10n(arabic).commonClose), findsOneWidget);
    });

    testWidgets('keeps its content clear of a landscape notch', (tester) async {
      tester.view.padding = const FakeViewPadding(left: 44, right: 44);
      await pumpSurface(
        tester,
        surfaces[2],
        _banner(surfaces[2], onAction: () {}),
        wrapInScaffold: false,
      );
      expectCleanLayout(tester);
      // The tint still runs edge to edge…
      expect(tester.getRect(find.byType(StatusBanner)).left, 0);
      // …but the icon and action sit inside the safe area.
      final icon = tester.getRect(find.byIcon(Icons.cloud_off_rounded));
      final action = tester.getRect(find.byType(TextButton));
      expect(icon.left, greaterThanOrEqualTo(44));
      expect(action.right, lessThanOrEqualTo(720 - 44));
    });
  });

  group('StatusBanner tint', () {
    for (final surface in [phoneEn, surfaces[3]]) {
      testWidgets('one colour drives fill, hairline, icon and text — $surface',
          (tester) async {
        await pumpSurface(tester, surface, _banner(surface));
        final material = tester.widget<Material>(find
            .descendant(
              of: find.byType(StatusBanner),
              matching: find.byType(Material),
            )
            .first);
        expect(material.color, _amber.withValues(alpha: Alphas.tint));

        final box = tester.widget<Container>(find.descendant(
          of: find.byType(StatusBanner),
          matching: find.byType(Container),
        ));
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.bottom.color, _amber.withValues(alpha: Alphas.border));
        expect(border.bottom.width, CompSz.hairline / 2);
        expect(border.top, BorderSide.none);

        final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded));
        expect(icon.color, _amber);
        final context = tester.element(find.byType(StatusBanner));
        expect(icon.size, context.r(IconSz.xs));

        final text = tester.widget<Text>(
          find.text(l10n(surface.locale).offlineNoQueue),
        );
        expect(text.style?.color, _amber);
        expect(text.style?.fontWeight, FontWeight.w700);
        expect(text.style?.fontSize, FontSz.sm);
      });
    }
  });
}
