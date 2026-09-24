import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/shared/widgets/app_button.dart';
import 'package:location_gps/shared/widgets/error_view.dart';

import 'widget_harness.dart';

const _phoneArDark = Surface('phone · ar · dark',
    size: Size(390, 844), locale: arabic, brightness: Brightness.dark);

/// The longest real failure sentence plus a company name — what a server
/// message quoting a record looks like.
String _longMessage(Surface s) =>
    '${l10n(s.locale).errUnknown} ${LongText.of(s)} ${LongText.of(s)}';

Finder get _button => find.byType(AppButton);

void main() {
  setUpAll(initHarness);

  group('ErrorView layout', () {
    testOnEverySurface(
      'a long message, a reference and a long action label fit',
      (s) => ErrorView(
        message: _longMessage(s),
        reference: 'server_error_${'9' * 24}',
        actionLabel: LongText.of(s),
        actionIcon: Icons.home_outlined,
        onRetry: () {},
      ),
      verify: (tester, s) async {
        final t = l10n(s.locale);
        expect(find.text(_longMessage(s)), findsOneWidget);
        expect(find.text(t.commonErrorReference('server_error_${'9' * 24}')),
            findsOneWidget);
        await tester.ensureVisible(_button);
        await tester.pump();
        final button = tester.getRect(_button);
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(s.size.width));
        expect(button.bottom, lessThanOrEqualTo(s.size.height));
      },
    );

    testOnEverySurface(
      'a message alone is centred',
      (s) => ErrorView(message: l10n(s.locale).errUnknown),
      verify: (tester, s) async {
        expect(_button, findsNothing);
        final center = tester.getCenter(find.text(l10n(s.locale).errUnknown));
        expect(center.dx, moreOrLessEquals(s.size.width / 2, epsilon: 1));
      },
    );

    testOnEverySurface(
      'inside a list (unbounded height) it shrink-wraps',
      (s) => ListView(
        children: [
          ErrorView(message: _longMessage(s), onRetry: () {}),
          const Text('after'),
        ],
      ),
    );
  });

  group('ErrorView retry', () {
    testWidgets('fires onRetry once per tap', (tester) async {
      var taps = 0;
      await pumpSurface(
        tester,
        phoneEn,
        ErrorView(message: 'Failed', onRetry: () => taps++),
      );
      await tester.tap(_button);
      await tester.pump();
      expect(taps, 1);
      await tester.tap(_button);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('no onRetry means no button at all', (tester) async {
      await pumpSurface(tester, phoneEn, const ErrorView(message: 'Failed'));
      expect(_button, findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text(l10n(english).commonRetry), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    for (final s in [phoneEn, phoneAr]) {
      testWidgets('the default label is the localized "Retry" — $s',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          ErrorView(message: l10n(s.locale).errUnknown, onRetry: () {}),
        );
        final t = l10n(s.locale);
        expect(find.text(t.commonRetry), findsOneWidget);
        expect(tester.widget<AppButton>(_button).label, t.commonRetry);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
      });
    }

    testWidgets('actionLabel and actionIcon replace the defaults',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        ErrorView(
          message: 'x',
          actionLabel: l10n(arabic).commonGoHome,
          actionIcon: Icons.home_outlined,
          onRetry: () {},
        ),
      );
      expect(find.text(l10n(arabic).commonGoHome), findsOneWidget);
      expect(find.text(l10n(arabic).commonRetry), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('an actionLabel without onRetry still shows nothing',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ErrorView(message: 'x', actionLabel: 'Go home'),
      );
      expect(find.text('Go home'), findsNothing);
    });

    testWidgets('the action is a secondary, content-width, 48dp+ button',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        ErrorView(message: 'x', onRetry: () {}),
      );
      final button = tester.widget<AppButton>(_button);
      expect(button.variant, AppButtonVariant.secondary);
      expect(button.fullWidth, isFalse);
      final size = tester.getSize(find.byType(OutlinedButton));
      expect(size.width, lessThan(phoneEn.size.width / 2));
      expect(size.height, greaterThanOrEqualTo(IconSz.hit));
    });
  });

  group('ErrorView content', () {
    for (final s in [phoneEn, phoneAr]) {
      testWidgets('the reference reads as the localized "Error code" — $s',
          (tester) async {
        await pumpSurface(
          tester,
          s,
          const ErrorView(message: 'm', reference: 'server'),
        );
        final line = l10n(s.locale).commonErrorReference('server');
        expect(find.text(line), findsOneWidget);
        expect(line, contains('server'));
        expect(line, isNot('server'), reason: 'the code is framed in words');
      });
    }

    testWidgets('no reference, no small print', (tester) async {
      await pumpSurface(tester, phoneEn, const ErrorView(message: 'm'));
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('an empty reference still shows its frame', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ErrorView(message: 'm', reference: ''),
      );
      expect(find.text(l10n(english).commonErrorReference('')), findsOneWidget);
    });

    testWidgets('order: icon, message, reference, action', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        ErrorView(message: 'msg', reference: 'code', onRetry: () {}),
      );
      final icon = tester.getRect(find.byIcon(Icons.error_outline));
      final message = tester.getRect(find.text('msg'));
      final reference = tester
          .getRect(find.text(l10n(english).commonErrorReference('code')));
      final action = tester.getRect(_button);
      expect(icon.bottom, lessThanOrEqualTo(message.top));
      expect(message.bottom, lessThanOrEqualTo(reference.top));
      expect(reference.bottom, lessThanOrEqualTo(action.top));
    });

    testWidgets('a custom icon replaces the default one', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const ErrorView(message: 'm', icon: Icons.wifi_off),
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('the glyph is 56dp scaled with the device', (tester) async {
      const small = Surface('small', size: Size(320, 568), locale: english);
      await pumpSurface(tester, small, const ErrorView(message: 'm'));
      expect(tester.widget<Icon>(find.byType(Icon)).size,
          moreOrLessEquals(CompSz.errorGlyph * 0.85));
    });

    testWidgets('message and reference are centred text', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const ErrorView(message: 'm', reference: 'r'),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.textAlign, TextAlign.center);
        expect(text.maxLines, isNull, reason: 'failures are never cut');
      }
    });
  });

  group('ErrorView theming', () {
    for (final s in [phoneEn, _phoneArDark]) {
      testWidgets('colours and type come from the theme — $s', (tester) async {
        await pumpSurface(
          tester,
          s,
          const ErrorView(message: 'msg', reference: 'code'),
        );
        final context = tester.element(find.byType(ErrorView));
        final theme = Theme.of(context);
        expect(theme.brightness, s.brightness);
        expect(tester.widget<Icon>(find.byType(Icon)).color,
            theme.colorScheme.error);
        expect(tester.widget<Text>(find.text('msg')).style,
            theme.textTheme.bodyLarge);
        final reference = tester.widget<Text>(find.text(
            l10n(s.locale).commonErrorReference('code')));
        expect(reference.style!.color, theme.colorScheme.onSurfaceVariant);
        expect(reference.style!.fontSize, theme.textTheme.bodySmall!.fontSize);
      });
    }
  });
}
