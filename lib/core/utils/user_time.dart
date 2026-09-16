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
  /// `utc` should be a UTC `DateTime` (use `parseOdooUtc` when parsing
  /// from server responses). Returns a `DateTime`-compatible value in the
  /// user's timezone — safe to pass to `DateFormat.format`.
  ///
  /// Outside a signed-in tree (a widget pumped on its own in a test, the
  /// setup screen) there is no user, so the device zone is used.
  DateTime toUserTime(DateTime utc) {
    String? tzName;
    try {
      tzName = read<AuthBloc>().state.user?.tz;
    } on ProviderNotFoundException {
      tzName = null;
    }
    if (tzName == null || tzName.isEmpty) return utc.toLocal();
    try {
      return tz.TZDateTime.from(utc, tz.getLocation(tzName));
    } catch (_) {
      // Unknown IANA name — fall back gracefully.
      return utc.toLocal();
    }
  }
}
