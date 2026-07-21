import 'package:flutter/foundation.dart';

/// Debug-only diagnostic logging.
///
/// Use this instead of [debugPrint] directly. `debugPrint` is **not** stripped
/// from release builds: whatever is passed to it is written to logcat on every
/// user's device, readable over adb and by anything holding `READ_LOGS`. Some
/// of this app's traces carry session payloads, logins, GPS fixes and customer
/// records, so every call site has to be gated on [kDebugMode].
///
/// A single helper is used rather than repeating `if (kDebugMode)` at each of
/// the ~20 call sites, because the site someone forgets to wrap is exactly the
/// one that leaks — and a forgotten guard is invisible in review.
void appLog(String message) {
  if (kDebugMode) debugPrint(message);
}
