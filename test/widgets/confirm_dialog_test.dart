import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/shared/widgets/confirm_dialog.dart';

import 'widget_harness.dart';

/// Opens the dialog from a real route, so `Navigator.pop` has somewhere to go.
Widget _launcher(
  Surface s,
  void Function(bool result) onResult, {
  DialogTone tone = DialogTone.destructive,
}) {
  final t = l10n(s.locale);
  return Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () async => onResult(await ConfirmDialog.show(
          context,
          title: t.confirmLogoutTitle,
          message: '${t.confirmLogoutMessage} ${t.errUnknown}',
          icon: Icons.logout_rounded,
          confirmLabel: t.commonLogout,
          cancelLabel: t.commonCancel,
          tone: tone,
        )),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  setUpAll(initHarness);

  group('ConfirmDialog layout', () {
    for (final tone in DialogTone.values) {
      testOnEverySurface(
        '${tone.name} dialog with a long message fits',
        (s) => _launcher(s, (_) {}, tone: tone),
        verify: (tester, s) async {
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.byType(ConfirmDialog), findsOneWidget);
          // Both actions stay reachable, whatever the viewport.
          expect(find.byType(OutlinedButton), findsOneWidget);
          expect(find.byType(FilledButton), findsOneWidget);
          final card = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Material),
          );
          expect(tester.getSize(card.first).width, lessThanOrEqualTo(560));
        },
      );
    }
  });

  group('ConfirmDialog behaviour', () {
    Future<bool?> run(WidgetTester tester, Finder tap) async {
      bool? result;
      await pumpSurface(tester, phoneEn, _launcher(phoneEn, (r) => result = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(tap);
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm returns true', (tester) async {
      expect(await run(tester, find.byType(FilledButton)), isTrue);
    });

    testWidgets('cancel returns false', (tester) async {
      expect(await run(tester, find.byType(OutlinedButton)), isFalse);
    });

    testWidgets('dismissing by tapping outside returns false', (tester) async {
      bool? result;
      await pumpSurface(tester, phoneEn, _launcher(phoneEn, (r) => result = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmDialog), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('the default labels are the localized yes / no',
        (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                ConfirmDialog.show(context, title: 'T', message: 'M'),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n(arabic).commonYes), findsOneWidget);
      expect(find.text(l10n(arabic).commonNo), findsOneWidget);
    });

    testWidgets('tone decides the confirm colour', (tester) async {
      Future<Color?> confirmColor(DialogTone tone) async {
        await pumpSurface(
          tester,
          phoneEn,
          ConfirmDialog(title: 'T', message: 'M', tone: tone),
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        return button.style?.backgroundColor?.resolve({});
      }

      final destructive = await confirmColor(DialogTone.destructive);
      final neutral = await confirmColor(DialogTone.neutral);
      final context = tester.element(find.byType(FilledButton));
      expect(destructive, Theme.of(context).colorScheme.error);
      expect(neutral, Theme.of(context).colorScheme.primary);
    });
  });

  testOnEverySurface(
    'AppDialogFrame with a single full-width action fits',
    (s) => AppDialogFrame(
      icon: Icons.location_on_rounded,
      title: l10n(s.locale).visitTrackingDisclosureTitle,
      body: Text(l10n(s.locale).visitTrackingDisclosureBody),
      actions: [
        FilledButton(
          onPressed: () {},
          child: Text(l10n(s.locale).visitTrackingDisclosureAgree),
        ),
      ],
    ),
  );
}
