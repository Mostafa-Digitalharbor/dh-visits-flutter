import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/features/visits/data/visit_tracking_consent.dart';
import 'package:location_gps/features/visits/view/visit_tracking_disclosure_dialog.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/widget_harness.dart';

const _agree = WidgetKeys.visitTrackingDisclosureAgree;
const _decline = WidgetKeys.visitTrackingDisclosureDecline;

/// Opens the dialog from a real route and records what it returned.
Widget _launcher(void Function(bool) onResult, {VisitTrackingConsent? consent}) =>
    Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async => onResult(consent == null
              ? await VisitTrackingDisclosureDialog.show(context)
              : await VisitTrackingDisclosureDialog.ensureAccepted(
                  context, consent)),
          child: const Text('open'),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Scrolls an answer into view (the dialog body scrolls) and taps it.
Future<void> _press(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initHarness);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('layout', () {
    testOnEverySurface(
      'the four paragraphs and both actions fit, scrolling if needed',
      (s) => _launcher((_) {}),
      verify: (tester, s) async {
        await _open(tester);
        final t = l10n(s.locale);
        expect(find.text(t.visitTrackingDisclosureTitle), findsOneWidget);
        for (final paragraph in [
          t.visitTrackingDisclosureBody,
          t.visitTrackingDisclosureStops,
          t.visitTrackingDisclosureStorage,
          t.visitTrackingDisclosureAndroid,
        ]) {
          expect(find.text(paragraph), findsOneWidget);
        }
        // Both answers are reachable and full-size, whatever the viewport.
        for (final key in [_agree, _decline]) {
          await tester.ensureVisible(find.byKey(key));
          await tester.pump();
          final size = tester.getSize(find.byKey(key));
          expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
          final rect = tester.getRect(find.byKey(key));
          expect(rect.bottom, lessThanOrEqualTo(s.size.height));
          expect(rect.top, greaterThanOrEqualTo(0));
        }
        expect(find.text(t.visitTrackingDisclosureAgree), findsOneWidget);
        expect(find.text(t.visitTrackingDisclosureDecline), findsOneWidget);
      },
    );
  });

  group('show', () {
    Future<bool?> answer(WidgetTester tester, Key key) async {
      bool? result;
      await pumpSurface(tester, phoneEn, _launcher((r) => result = r));
      await _open(tester);
      await _press(tester, key);
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      return result;
    }

    testWidgets('agree returns true', (tester) async {
      expect(await answer(tester, _agree), isTrue);
    });

    testWidgets('decline returns false', (tester) async {
      expect(await answer(tester, _decline), isFalse);
    });

    testWidgets('a tap outside does not dismiss it', (tester) async {
      bool? result;
      await pumpSurface(tester, phoneEn, _launcher((r) => result = r));
      await _open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('system back counts as a decline', (tester) async {
      bool? result;
      await pumpSurface(tester, phoneEn, _launcher((r) => result = r));
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('decline comes first, agree at the end, mirrored in Arabic',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, _launcher((_) {}));
        await _open(tester);
        final decline = tester.getCenter(find.byKey(_decline)).dx;
        final agree = tester.getCenter(find.byKey(_agree)).dx;
        expect(decline < agree, s == phoneEn, reason: s.name);
        expect(find.byType(FilledButton), findsOneWidget,
            reason: 'agree is the primary action');
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).key,
          _agree,
        );
        await _press(tester, _decline);
      }
    });

    testWidgets('names the location glyph and is written in Arabic',
        (tester) async {
      await pumpSurface(tester, phoneAr, _launcher((_) {}));
      await _open(tester);
      final t = l10n(arabic);
      expect(find.byIcon(Symbols.share_location), findsOneWidget);
      expect(find.text(t.visitTrackingDisclosureTitle), findsOneWidget);
      expect(find.text(t.visitTrackingDisclosureAgree), findsOneWidget);
      final body = tester.widget<Text>(find.text(t.visitTrackingDisclosureBody));
      final context = tester.element(find.text(t.visitTrackingDisclosureBody));
      expect(body.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
    });

    testWidgets('on iOS the iOS paragraph replaces the Android one',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpSurface(tester, phoneEn, _launcher((_) {}));
        await _open(tester);
        final t = l10n(english);
        expect(find.text(t.visitTrackingDisclosureIos), findsOneWidget);
        expect(find.text(t.visitTrackingDisclosureAndroid), findsNothing);
        await _press(tester, _decline);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('ensureAccepted', () {
    testWidgets('already accepted: true, and no dialog', (tester) async {
      await prefs.setBool(VisitTrackingConsent.key, true);
      bool? result;
      await pumpSurface(
        tester,
        phoneEn,
        _launcher((r) => result = r, consent: VisitTrackingConsent(prefs)),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('no store (widget tests): treated as accepted',
        (tester) async {
      bool? result;
      await pumpSurface(
        tester,
        phoneEn,
        _launcher((r) => result = r, consent: const VisitTrackingConsent(null)),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('agreeing remembers it; the next start asks nothing',
        (tester) async {
      final consent = VisitTrackingConsent(prefs);
      final results = <bool>[];
      await pumpSurface(
          tester, phoneEn, _launcher(results.add, consent: consent));
      await _open(tester);
      expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
      await _press(tester, _agree);
      expect(results, [true]);
      expect(prefs.getBool(VisitTrackingConsent.key), isTrue);
      expect(consent.accepted, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(VisitTrackingDisclosureDialog), findsNothing);
      expect(results, [true, true]);
    });

    testWidgets('declining stores nothing and asks again next time',
        (tester) async {
      final consent = VisitTrackingConsent(prefs);
      final results = <bool>[];
      await pumpSurface(
          tester, phoneEn, _launcher(results.add, consent: consent));
      await _open(tester);
      await _press(tester, _decline);
      expect(results, [false]);
      expect(prefs.getBool(VisitTrackingConsent.key), isNull);

      await _open(tester);
      expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
    });

    testWidgets('a corrupt stored value asks again', (tester) async {
      SharedPreferences.setMockInitialValues(
          {VisitTrackingConsent.key: 'yes'});
      final odd = await SharedPreferences.getInstance();
      bool? result;
      await pumpSurface(
        tester,
        phoneEn,
        _launcher((r) => result = r, consent: VisitTrackingConsent(odd)),
      );
      await _open(tester);
      expect(find.byType(VisitTrackingDisclosureDialog), findsOneWidget);
      await _press(tester, _agree);
      expect(result, isTrue);
    });
  });
}
