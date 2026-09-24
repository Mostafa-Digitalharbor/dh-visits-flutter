import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/features/visits/view/visit_schedule_picker.dart';

import '../../widgets/widget_harness.dart';

class _Result {
  bool done = false;
  DateTime? value;
}

Widget _launcher(DateTime? current, _Result result) => Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async {
            result.value = await pickVisitSchedule(context, current: current);
            result.done = true;
          },
          child: const Text('open'),
        ),
      ),
    );

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Future<_Result> _openPicker(
  WidgetTester tester,
  DateTime? current, {
  Surface surface = phoneEn,
}) async {
  final result = _Result();
  await pumpSurface(tester, surface, _launcher(current, result));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

DatePickerDialog _datePicker(WidgetTester tester) =>
    tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

Future<void> _press(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initHarness);

  group('the date step', () {
    testWidgets('opens on the current slot when it is in the window',
        (tester) async {
      final current = DateTime.now().add(const Duration(days: 10));
      await _openPicker(tester, current);
      final picker = _datePicker(tester);
      expect(_day(picker.initialDate!), _day(current));
    });

    testWidgets('an overdue slot opens on today instead of asserting',
        (tester) async {
      final overdue = DateTime.now().subtract(const Duration(days: 40));
      await _openPicker(tester, overdue);
      expect(tester.takeException(), isNull);
      expect(_day(_datePicker(tester).initialDate!), _day(DateTime.now()));
    });

    testWidgets('a slot past the window opens on today', (tester) async {
      final far = DateTime.now().add(const Duration(days: 800));
      await _openPicker(tester, far);
      expect(tester.takeException(), isNull);
      expect(_day(_datePicker(tester).initialDate!), _day(DateTime.now()));
    });

    testWidgets('a slot inside the grace day is kept', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(hours: 20));
      await _openPicker(tester, yesterday);
      expect(_day(_datePicker(tester).initialDate!), _day(yesterday));
    });

    testWidgets('no slot opens on today', (tester) async {
      await _openPicker(tester, null);
      expect(_day(_datePicker(tester).initialDate!), _day(DateTime.now()));
    });

    testWidgets('a UTC slot is shown on its local day', (tester) async {
      final local = DateTime.now().add(const Duration(days: 5));
      await _openPicker(tester, local.toUtc());
      expect(_day(_datePicker(tester).initialDate!), _day(local));
    });

    testWidgets('the window runs from the grace period to the max ahead',
        (tester) async {
      await _openPicker(tester, null);
      final picker = _datePicker(tester);
      final now = DateTime.now();
      expect(_day(picker.firstDate),
          _day(now.subtract(AppConstants.visitSchedulePastGrace)));
      expect(_day(picker.lastDate),
          _day(now.add(AppConstants.visitScheduleMaxAhead)));
    });

    testWidgets('backing out of the date returns null, no time step',
        (tester) async {
      final result = await _openPicker(tester, null);
      await _press(tester, 'Cancel');
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(result.done, isTrue);
      expect(result.value, isNull);
    });

    testWidgets('the pickers follow the app language', (tester) async {
      await _openPicker(tester, null, surface: phoneAr);
      final context = tester.element(find.byType(DatePickerDialog));
      final m = MaterialLocalizations.of(context);
      expect(find.text(m.okButtonLabel), findsOneWidget);
      expect(Directionality.of(context), TextDirection.rtl);
      await tester.tap(find.text(m.cancelButtonLabel));
      await tester.pumpAndSettle();
    });
  });

  group('the time step', () {
    testWidgets('starts on the current time of day', (tester) async {
      final current = DateTime.now().add(const Duration(days: 2));
      final slot =
          DateTime(current.year, current.month, current.day, 14, 45);
      await _openPicker(tester, slot);
      await _press(tester, 'OK');
      final picker =
          tester.widget<TimePickerDialog>(find.byType(TimePickerDialog));
      expect(picker.initialTime, const TimeOfDay(hour: 14, minute: 45));
    });

    testWidgets('confirming both returns the chosen day at that time',
        (tester) async {
      final current = DateTime.now().add(const Duration(days: 2));
      final slot = DateTime(current.year, current.month, current.day, 9, 5);
      final result = await _openPicker(tester, slot);
      await _press(tester, 'OK');
      await _press(tester, 'OK');
      expect(result.value, slot);
    });

    testWidgets('backing out of the time keeps the date and the old time',
        (tester) async {
      final current = DateTime.now().add(const Duration(days: 2));
      final slot = DateTime(current.year, current.month, current.day, 16, 20);
      final result = await _openPicker(tester, slot);
      await _press(tester, 'OK');
      await _press(tester, 'Cancel');
      expect(result.done, isTrue);
      expect(result.value, slot);
    });

    testWidgets('an overdue slot moved to today keeps its time of day',
        (tester) async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 30));
      final overdue = DateTime(old.year, old.month, old.day, 8, 15);
      final result = await _openPicker(tester, overdue);
      await _press(tester, 'OK');
      await _press(tester, 'Cancel');
      expect(result.value, DateTime(now.year, now.month, now.day, 8, 15));
    });

    testWidgets('the seconds of the old slot are dropped', (tester) async {
      final current = DateTime.now().add(const Duration(days: 1));
      final slot =
          DateTime(current.year, current.month, current.day, 11, 30, 42);
      final result = await _openPicker(tester, slot);
      await _press(tester, 'OK');
      await _press(tester, 'OK');
      expect(result.value,
          DateTime(current.year, current.month, current.day, 11, 30));
    });
  });

  group('layout', () {
    testOnEverySurface(
      'the date and time dialogs fit',
      (s) => _launcher(DateTime.now(), _Result()),
      verify: (tester, s) async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        final m = MaterialLocalizations.of(
            tester.element(find.byType(DatePickerDialog)));
        await tester.tap(find.text(m.okButtonLabel));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text(m.cancelButtonLabel));
        await tester.pumpAndSettle();
      },
    );
  });
}
