import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/utils/app_date.dart';
import 'package:location_gps/features/visits/view/action_sheets.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';

const _longReason =
    'رفض العميل الموعد المقترح بسبب انشغال فريق المشتريات بإغلاق الربع المالي '
    'وطلب إعادة الجدولة إلى الأسبوع القادم بعد التنسيق مع مدير المشروع';

/// What a sheet returned, and whether it has returned at all.
class _Outcome<T> {
  bool done = false;
  T? value;
}

/// Opens [open] from a real route when "open" is tapped.
Widget _launcher<T>(
  Future<T?> Function(BuildContext) open,
  _Outcome<T> outcome,
) =>
    Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            outcome.value = await open(context);
            outcome.done = true;
          },
          child: const Text('open'),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(AppButton),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// `OutlinedButton.icon` builds a private subclass, which `byType` misses.
final _scheduleButton = find.byWidgetPredicate((w) => w is OutlinedButton);

final _schedule = () {
  final d = DateTime.now().add(const Duration(days: 3));
  return DateTime(d.year, d.month, d.day, 10, 30);
}();

void main() {
  setUpAll(initHarness);

  group('layout', () {
    for (final (name, open) in <(String, Future<Object?> Function(BuildContext))>[
      ('reject reason', showRejectReasonSheet),
      (
        'end visit',
        (c) => showEndVisitSheet(c, initial: '$_longReason $_longReason'),
      ),
      (
        'reschedule',
        (c) => showRescheduleSheet(
              c,
              initialSchedule: _schedule,
              initialPurpose: _longReason,
              initialLocation: LongText.arabicCompany,
            ),
      ),
    ]) {
      testOnEverySurface(
        'the $name sheet fits, submit reachable',
        (s) => _launcher(open, _Outcome()),
        verify: (tester, s) async {
          await _open(tester);
          expect(find.byType(BottomSheet), findsOneWidget);
          final button = find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(AppButton));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(tester.getRect(button).bottom,
              lessThanOrEqualTo(s.size.height));
          expect(find.byTooltip(l10n(s.locale).commonClose), findsOneWidget);
        },
      );

      testWidgets('the $name sheet stays usable above a keyboard on 320×568',
          (tester) async {
        const keyboard = 260.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        final s = surfaces[0];
        await pumpSurface(tester, s, _launcher(open, _Outcome()));
        await _open(tester);
        expectCleanLayout(tester);
        final button = find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(AppButton));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getRect(button).bottom,
            lessThanOrEqualTo(s.size.height - keyboard + 1));
        expectCleanLayout(tester);
      });
    }
  });

  group('showRejectReasonSheet', () {
    Future<_Outcome<String>> pumpReject(WidgetTester tester,
        {Surface s = phoneEn}) async {
      final outcome = _Outcome<String>();
      await pumpSurface(tester, s, _launcher(showRejectReasonSheet, outcome));
      await _open(tester);
      return outcome;
    }

    testWidgets('titles and hints come from the ARB, in Arabic too',
        (tester) async {
      await pumpReject(tester, s: phoneAr);
      final t = l10n(arabic);
      expect(find.text(t.wfRejectReason), findsOneWidget);
      expect(find.text(t.wfRejectReasonHint), findsOneWidget);
      expect(find.text(t.wfActionReject), findsOneWidget);
    });

    testWidgets('a reason is required, blank or whitespace alike',
        (tester) async {
      final outcome = await pumpReject(tester);
      final t = l10n(english);
      await _submit(tester);
      expect(find.text(t.wfReasonRequired), findsOneWidget);
      expect(outcome.done, isFalse);

      await tester.enterText(find.byType(TextField), '   \n  ');
      await tester.pump();
      // Typing clears the error...
      expect(find.text(t.wfReasonRequired), findsNothing);
      // ...and whitespace is still no reason.
      await _submit(tester);
      expect(find.text(t.wfReasonRequired), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('returns the trimmed reason and closes', (tester) async {
      final outcome = await pumpReject(tester);
      await tester.enterText(find.byType(TextField), '  $_longReason \n');
      await _submit(tester);
      expect(outcome.done, isTrue);
      expect(outcome.value, _longReason);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('closing returns null', (tester) async {
      final outcome = await pumpReject(tester);
      await tester.enterText(find.byType(TextField), 'draft reason');
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await tester.pumpAndSettle();
      expect(outcome.done, isTrue);
      expect(outcome.value, isNull);
    });

    testWidgets('the field takes focus and three lines; the button is red',
        (tester) async {
      await pumpReject(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.maxLines, 3);
      expect(field.textInputAction, TextInputAction.newline);
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.variant, AppButtonVariant.destructive);
    });

    testWidgets('a long error wraps instead of clipping', (tester) async {
      await pumpReject(tester, s: surfaces[0]);
      await _submit(tester);
      final decorator =
          tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.decoration.errorMaxLines, 3);
      expectCleanLayout(tester);
    });
  });

  group('showEndVisitSheet', () {
    Future<_Outcome<String>> pumpEnd(
      WidgetTester tester, {
      String? initial,
      Surface s = phoneEn,
    }) async {
      final outcome = _Outcome<String>();
      await pumpSurface(
        tester,
        s,
        _launcher((c) => showEndVisitSheet(c, initial: initial), outcome),
      );
      await _open(tester);
      return outcome;
    }

    testWidgets('an outcome is required', (tester) async {
      final outcome = await pumpEnd(tester, s: phoneAr);
      final t = l10n(arabic);
      expect(find.text(t.wfFieldOutcome), findsOneWidget);
      expect(find.text(t.wfActionEnd), findsNWidgets(2),
          reason: 'the title and the button');
      await _submit(tester);
      expect(find.text(t.wfOutcomeRequired), findsOneWidget);
      expect(outcome.done, isFalse);
    });

    testWidgets('prefills the recorded outcome and returns it trimmed',
        (tester) async {
      final outcome = await pumpEnd(tester, initial: '  Signed the PO  ');
      expect(find.text('  Signed the PO  '), findsOneWidget);
      await _submit(tester);
      expect(outcome.value, 'Signed the PO');
    });

    testWidgets('a whitespace-only prefill is still required',
        (tester) async {
      final outcome = await pumpEnd(tester, initial: '   ');
      await _submit(tester);
      expect(find.text(l10n(english).wfOutcomeRequired), findsOneWidget);
      expect(outcome.done, isFalse);
    });

    testWidgets('four lines, the stop glyph, a primary button',
        (tester) async {
      await pumpEnd(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 4);
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.variant, AppButtonVariant.primary);
      expect(button.icon, Icons.stop_circle_outlined);
    });

    testWidgets('closing returns null', (tester) async {
      final outcome = await pumpEnd(tester, initial: 'x');
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await tester.pumpAndSettle();
      expect((outcome.done, outcome.value), (true, null));
    });
  });

  group('showRescheduleSheet', () {
    Future<_Outcome<RescheduleResult>> pumpReschedule(
      WidgetTester tester, {
      DateTime? schedule,
      String? purpose = 'Contract review',
      String? location = 'Olaya St',
      Surface s = phoneEn,
    }) async {
      final outcome = _Outcome<RescheduleResult>();
      await pumpSurface(
        tester,
        s,
        _launcher(
          (c) => showRescheduleSheet(
            c,
            initialSchedule: schedule,
            initialPurpose: purpose,
            initialLocation: location,
          ),
          outcome,
        ),
      );
      await _open(tester);
      return outcome;
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('nothing changed: the localized hint, and the sheet stays',
        (tester) async {
      for (final s in const [phoneEn, phoneAr]) {
        final outcome = await pumpReschedule(tester, schedule: _schedule, s: s);
        await _submit(tester);
        final t = l10n(s.locale);
        expect(find.text(t.wfRescheduleNoChanges), findsOneWidget);
        expect(outcome.done, isFalse);
        expect(find.byType(BottomSheet), findsOneWidget);
        final context = tester.element(find.text(t.wfRescheduleNoChanges));
        expect(
          tester.widget<Text>(find.text(t.wfRescheduleNoChanges)).style?.color,
          Theme.of(context).colorScheme.error,
        );
      }
    });

    testWidgets('trailing spaces are not a change', (tester) async {
      final outcome = await pumpReschedule(tester);
      final t = l10n(english);
      await tester.enterText(field(t.wfFieldPurpose), '  Contract review  ');
      await _submit(tester);
      expect(find.text(t.wfRescheduleNoChanges), findsOneWidget);
      expect(outcome.done, isFalse);
    });

    testWidgets('editing a field clears the hint', (tester) async {
      await pumpReschedule(tester);
      final t = l10n(english);
      await _submit(tester);
      expect(find.text(t.wfRescheduleNoChanges), findsOneWidget);
      await tester.enterText(field(t.wfFieldLocation), 'Olaya St 2');
      await tester.pump();
      expect(find.text(t.wfRescheduleNoChanges), findsNothing);
    });

    testWidgets('a new purpose is sent, trimmed, with the rest unchanged',
        (tester) async {
      final outcome = await pumpReschedule(tester, schedule: _schedule);
      await tester.enterText(
          field(l10n(english).wfFieldPurpose), '  Price negotiation ');
      await _submit(tester);
      expect(outcome.done, isTrue);
      final r = outcome.value!;
      expect(r.purpose, 'Price negotiation');
      expect(r.location, 'Olaya St');
      expect(r.scheduled, _schedule);
    });

    testWidgets('clearing the location is a change and sends null',
        (tester) async {
      final outcome = await pumpReschedule(tester);
      await tester.enterText(field(l10n(english).wfFieldLocation), '   ');
      await _submit(tester);
      expect(outcome.value!.location, isNull);
      expect(outcome.value!.purpose, 'Contract review');
      expect(outcome.value!.scheduled, isNull);
    });

    testWidgets('with nothing prefilled, blanks are no change',
        (tester) async {
      final outcome =
          await pumpReschedule(tester, purpose: null, location: null);
      final t = l10n(english);
      await tester.enterText(field(t.wfFieldPurpose), '  ');
      await _submit(tester);
      expect(find.text(t.wfRescheduleNoChanges), findsOneWidget);
      expect(outcome.done, isFalse);
    });

    testWidgets('the schedule button shows the current slot, or the label',
        (tester) async {
      await pumpReschedule(tester, schedule: _schedule, s: phoneAr);
      final context = tester.element(find.byType(BottomSheet));
      expect(find.text(AppDate.weekdayDateTime(context, _schedule)),
          findsOneWidget);
      await tester.tap(find.byTooltip(l10n(arabic).commonClose));
      await tester.pumpAndSettle();

      await pumpReschedule(tester);
      expect(
        find.descendant(
          of: _scheduleButton,
          matching: find.text(l10n(english).wfFieldSchedule),
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking a new slot is a change, and clears the hint',
        (tester) async {
      final outcome = await pumpReschedule(tester, schedule: _schedule);
      await _submit(tester);
      expect(find.text(l10n(english).wfRescheduleNoChanges), findsOneWidget);

      await tester.tap(_scheduleButton);
      await tester.pumpAndSettle();
      // Move the date on by a day, then keep 10:30.
      final next = _schedule.add(const Duration(days: 1));
      final dayCell = find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${next.day}'),
      );
      if (next.month != _schedule.month) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(dayCell.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text(l10n(english).wfRescheduleNoChanges), findsNothing);
      final context = tester.element(find.byType(BottomSheet));
      expect(find.text(AppDate.weekdayDateTime(context, next)), findsOneWidget);

      await _submit(tester);
      expect(outcome.value!.scheduled, next);
      expect(outcome.value!.purpose, 'Contract review');
    });

    testWidgets('backing out of the picker changes nothing', (tester) async {
      final outcome = await pumpReschedule(tester, schedule: _schedule);
      await tester.tap(_scheduleButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(find.text(l10n(english).wfRescheduleNoChanges), findsOneWidget);
      expect(outcome.done, isFalse);
    });

    testWidgets('closing returns null', (tester) async {
      final outcome = await pumpReschedule(tester);
      await tester.tap(find.byTooltip(l10n(english).commonClose));
      await tester.pumpAndSettle();
      expect((outcome.done, outcome.value), (true, null));
    });
  });
}
