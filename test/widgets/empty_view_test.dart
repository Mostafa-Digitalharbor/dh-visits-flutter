import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/ambient_pulse.dart';
import 'package:location_gps/shared/widgets/app_button.dart';
import 'package:location_gps/shared/widgets/empty_view.dart';

import 'widget_harness.dart';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

/// A sentence long enough to wrap several times at 320dp and 1.25×.
String _longMessage(Surface s) =>
    '${l10n(s.locale).customersEmpty} ${LongText.of(s)} ${LongText.of(s)}';

/// The halo: the one Container painted with a radial gradient.
Container _halo(WidgetTester tester) => tester
    .widgetList<Container>(find.descendant(
      of: find.byType(EmptyView),
      matching: find.byType(Container),
    ))
    .singleWhere((c) {
  final d = c.decoration;
  return d is BoxDecoration && d.gradient is RadialGradient;
});

double _haloAlpha(WidgetTester tester) =>
    ((_halo(tester).decoration! as BoxDecoration).gradient! as RadialGradient)
        .colors
        .first
        .a;

void main() {
  setUpAll(initHarness);

  group('EmptyView layout', () {
    testOnEverySurface(
      'a long message with an action fits (scrolling when short)',
      (s) => EmptyView(
        message: _longMessage(s),
        icon: Icons.people_outline,
        action: AppButton(
          label: l10n(s.locale).commonRetry,
          icon: Icons.refresh,
          onPressed: () {},
        ),
      ),
      verify: (tester, s) async {
        expect(find.text(_longMessage(s)), findsOneWidget);
        expect(find.byType(AppButton), findsOneWidget);
        // The action stays reachable: scroll to it if the viewport is short.
        await tester.ensureVisible(find.byType(AppButton));
        await tester.pump();
        final button = tester.getRect(find.byType(AppButton));
        expect(button.bottom, lessThanOrEqualTo(s.size.height));
        expect(button.top, greaterThanOrEqualTo(0));
      },
    );

    testOnEverySurface(
      'a short message without an action is centred',
      (s) => EmptyView(message: l10n(s.locale).customersEmpty),
      verify: (tester, s) async {
        expect(find.byType(AppButton), findsNothing);
        final text = tester.getCenter(find.text(l10n(s.locale).customersEmpty));
        // Horizontally centred on the screen.
        expect(text.dx, moreOrLessEquals(s.size.width / 2, epsilon: 1));
      },
    );

    testOnEverySurface(
      'inside a list (unbounded height) it shrink-wraps instead of throwing',
      (s) => ListView(
        children: [
          Text(l10n(s.locale).commonSearch),
          EmptyView(message: _longMessage(s)),
          const Text('after'),
        ],
      ),
      verify: (tester, s) async {
        expect(find.text(_longMessage(s)), findsOneWidget);
        // No inner viewport was created for it.
        expect(
          find.descendant(
            of: find.byType(EmptyView),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('in landscape at 1.25× the column scrolls instead of overflowing',
        (tester) async {
      const short = Surface('landscape · en · 1.25x',
          size: Size(720, 360),
          locale: english,
          textScale: Responsive.maxTextScale);
      await pumpSurface(
        tester,
        short,
        EmptyView(
          message: _longMessage(short),
          action: AppButton(label: 'Go', onPressed: () {}),
        ),
      );
      expectCleanLayout(tester);
      expect(
        find.descendant(
          of: find.byType(EmptyView),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });
  });

  group('EmptyView content', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('shows the localized message centred — $s', (tester) async {
        await pumpSurface(
          tester,
          s,
          EmptyView(message: l10n(s.locale).customersEmpty),
        );
        final text = tester.widget<Text>(
            find.text(l10n(s.locale).customersEmpty));
        expect(text.textAlign, TextAlign.center);
        expect(text.maxLines, isNull, reason: 'the message is never cut');
      });
    }

    testWidgets('the default icon is the inbox', (tester) async {
      await pumpSurface(tester, phoneEn, const EmptyView(message: 'm'));
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('a custom icon replaces it', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const EmptyView(message: 'm', icon: Icons.event_busy),
      );
      expect(find.byIcon(Icons.event_busy), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('the action sits below the message and fires once',
        (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        EmptyView(
          message: 'Nothing yet',
          action: AppButton(label: 'Add', onPressed: () => taps++),
        ),
      );
      expect(tester.getRect(find.byType(AppButton)).top,
          greaterThan(tester.getRect(find.text('Nothing yet')).bottom));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('an empty message still lays out', (tester) async {
      await pumpSurface(tester, phoneEn, const EmptyView(message: ''));
      expectCleanLayout(tester);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('halo and disc scale with the device width', (tester) async {
      const small = Surface('small', size: Size(320, 568), locale: english);
      await pumpSurface(tester, small, const EmptyView(message: 'm'));
      expect(tester.getSize(find.byWidget(_halo(tester))),
          const Size(130 * 0.85, 130 * 0.85));
      expect(tester.widget<Icon>(find.byType(Icon)).size,
          moreOrLessEquals(36 * 0.85));
      final disc = tester.getSize(find
          .ancestor(of: find.byType(Icon), matching: find.byType(Container))
          .first);
      expect(disc.width, moreOrLessEquals(78 * 0.85));
    });
  });

  group('EmptyView halo pulse', () {
    testWidgets('brightest at the start of a beat, dimmest when it ends',
        (tester) async {
      await pumpSurface(tester, phoneEn, const EmptyView(message: 'm'),
          settle: Duration.zero);
      expect(find.byType(AmbientPulse), findsOneWidget);
      expect(_haloAlpha(tester), moreOrLessEquals(0.32, epsilon: 0.005));

      await tester.pump(const Duration(milliseconds: 600));
      final mid = _haloAlpha(tester);
      expect(mid, lessThan(0.32));
      expect(mid, greaterThan(0.22));

      await tester.pump(const Duration(milliseconds: 600));
      expect(_haloAlpha(tester), moreOrLessEquals(0.22, epsilon: 0.005));
    });

    testWidgets('rests without scheduling frames, then beats again',
        (tester) async {
      await pumpSurface(tester, phoneEn, const EmptyView(message: 'm'),
          settle: Duration.zero);
      // An AnimationController reports completion on the first frame *past*
      // its duration, so the beat ends at 1201ms and the rest starts there.
      await tester.pump(const Duration(milliseconds: 1201));
      // The rest gap: nothing animates, so the app can idle.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_haloAlpha(tester), moreOrLessEquals(0.22, epsilon: 0.005));

      // The rest ends and the next beat starts bright.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_haloAlpha(tester), greaterThan(0.3));
    });

    testWidgets('disposing mid-rest leaves no timer behind', (tester) async {
      await pumpSurface(tester, phoneEn, const EmptyView(message: 'm'),
          settle: Duration.zero);
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyView theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('colours come from the theme — $s', (tester) async {
        await pumpSurface(tester, s, const EmptyView(message: 'Nothing'));
        final context = tester.element(find.byType(EmptyView));
        final cs = Theme.of(context).colorScheme;
        expect(Theme.of(context).brightness, s.brightness);

        expect(tester.widget<Icon>(find.byType(Icon)).color, cs.primary);
        expect(tester.widget<Text>(find.text('Nothing')).style!.color,
            cs.onSurfaceVariant);

        final halo = (_halo(tester).decoration! as BoxDecoration).gradient!
            as RadialGradient;
        final tint = Color.lerp(cs.primary, cs.tertiary, 0.5)!;
        expect(halo.colors.first.r, moreOrLessEquals(tint.r));
        expect(halo.colors.first.g, moreOrLessEquals(tint.g));
        expect(halo.colors.first.b, moreOrLessEquals(tint.b));
        expect(halo.colors.last, Colors.transparent);

        final disc = tester
            .widgetList<Container>(find.ancestor(
              of: find.byType(Icon),
              matching: find.byType(Container),
            ))
            .first;
        final discDecoration = disc.decoration! as BoxDecoration;
        expect((discDecoration.gradient! as LinearGradient).colors,
            [cs.surfaceContainerHighest, cs.surfaceContainerHigh]);
        expect((discDecoration.border! as Border).top.color,
            cs.outlineVariant);
      });
    }
  });
}
