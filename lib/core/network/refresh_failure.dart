import '../api/api_exceptions.dart';
import 'connectivity_status.dart';

extension RefreshFailure on ApiException {
  /// Whether a reload that failed over data already on screen deserves its
  /// own message.
  ///
  /// Not while the device is offline and the failure is only that: the
  /// offline banner already says so, and the offline queue reloads the screen
  /// once it syncs. The extra snackbar used to replace the "saved offline"
  /// confirmation of the action the user had just taken (emulator,
  /// 2026-09-17).
  bool worthAnnouncing(ConnectivityStatus? connectivity) {
    final connectivityOnly =
        code == ApiErrorCode.network || code == ApiErrorCode.timeout;
    return !(connectivityOnly && connectivity?.isOnline == false);
  }
}
