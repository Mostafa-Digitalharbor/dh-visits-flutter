import 'package:flutter/material.dart';

import '../../../core/constants.dart';

/// Asks for a visit's date, then its time, within the window a visit may be
/// scheduled in. Returns null when the user backs out of the date.
///
/// Backing out of the *time* keeps [current]'s time of day (or now's): the
/// date was the deliberate choice, and a second cancel should not discard it.
///
/// Shared by the create form and the reschedule sheet, which each had their own
/// copy — and both opened the date picker on [current] even when it was
/// already outside the window. For an overdue visit, the usual reason to
/// reschedule, that tripped `showDatePicker`'s range assertion.
Future<DateTime?> pickVisitSchedule(
  BuildContext context, {
  DateTime? current,
}) async {
  final now = DateTime.now();
  final first = now.subtract(AppConstants.visitSchedulePastGrace);
  final last = now.add(AppConstants.visitScheduleMaxAhead);
  final base = current?.toLocal() ?? now;
  final initial = base.isBefore(first) || base.isAfter(last) ? now : base;

  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
  );
  final t = time ?? TimeOfDay.fromDateTime(base);
  return DateTime(date.year, date.month, date.day, t.hour, t.minute);
}
