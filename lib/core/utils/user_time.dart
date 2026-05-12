import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/auth/bloc/auth_bloc.dart';

/// Converts a UTC datetime to the **Odoo user's preferred timezone**
/// (`res.users.tz`), falling back to the device clock when the user hasn't
/// set a timezone on their account.
///
/// Use this for every visit-time display so what the user sees in the app
/// matches what they'd see in Odoo Web for their account.
extension UserTime on BuildContext {
  /// `utc` should be a UTC `DateTime` (use `_parseOdooUtc` when parsing
  /// from server responses). Returns a `DateTime`-compatible value in the
  /// user's timezone — safe to pass to `DateFormat.format`.
  DateTime toUserTime(DateTime utc) {
    final tzName = read<AuthBloc>().state.user?.tz;
    if (tzName == null || tzName.isEmpty) {
      return utc.toLocal();
    }
    try {
      final loc = tz.getLocation(tzName);
      return tz.TZDateTime.from(utc, loc);
    } catch (_) {
      // Unknown IANA name — fall back gracefully.
      return utc.toLocal();
    }
  }
}
