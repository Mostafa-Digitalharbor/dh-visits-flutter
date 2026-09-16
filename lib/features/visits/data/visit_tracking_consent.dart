import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';

/// Whether this install has shown the visit-tracking disclosure and the user
/// agreed to it.
///
/// Read by the Start Visit button (before the first start), by the shell
/// restoring a visit that is already in progress (started on another device,
/// or before this install showed the disclosure), and by [VisitTrailTracker]
/// itself, which never starts capture without it.
class VisitTrackingConsent {
  /// Null (widget tests): treated as already accepted.
  final SharedPreferences? prefs;
  const VisitTrackingConsent(this.prefs);

  /// Bump the key's version when the disclosure text changes materially, so
  /// every user reads the new one before their next Start.
  static const String key = StorageKeys.visitTrackingDisclosure;

  bool get accepted {
    final store = prefs;
    if (store == null) return true;
    try {
      return store.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept() async {
    await prefs?.setBool(key, true);
  }
}
