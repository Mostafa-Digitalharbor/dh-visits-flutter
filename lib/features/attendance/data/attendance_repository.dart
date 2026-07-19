import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';

/// Mirrors the salesperson's visit check-in / check-out into Odoo's standard
/// **`hr.attendance`** so it shows up in the Attendances app, with the phone's
/// GPS landing in the native `in_latitude/in_longitude` and
/// `out_latitude/out_longitude` fields (Odoo even reverse-geocodes them into
/// `in_location`/`out_location`). No custom Odoo module required.
///
/// **Why the systray route and not `hr.attendance.create`:** a regular
/// employee is *not* allowed to `create` an `hr.attendance` row over RPC
/// (that ACL is reserved for Attendance Officers). Odoo's own web check-in
/// button avoids this by calling the [Endpoints.attendanceSystray] route,
/// which runs with elevated rights server-side and clocks the *current* user's
/// employee in/out. We use the exact same route, so it works for every field
/// user without granting them broad attendance permissions.
///
/// Everything here is **best-effort**: the caller wraps each method so an
/// attendance failure never blocks the visit check-in/out itself.
class AttendanceRepository {
  final ApiClient api;
  final SessionStorage session;

  AttendanceRepository({required this.api, required this.session});

  Future<int?> _uid() async {
    final u = await session.getUser();
    return (u?['uid'] as num?)?.toInt();
  }

  /// Whether the current user already has an open attendance (checked in, not
  /// yet checked out). Regular users can read their *own* attendance rows, so
  /// this is a side-effect-free way to know the current state and pick the
  /// right direction (instead of blindly toggling).
  Future<bool> _hasOpenAttendance(int uid) async {
    final count = await api.searchCount(
      AppConstants.hrAttendanceModel,
      domain: [
        ['employee_id.user_id', '=', uid],
        ['check_out', '=', false],
      ],
    );
    return count > 0;
  }

  /// Toggles the current user's attendance via Odoo's native systray endpoint,
  /// recording [latitude]/[longitude]. Returns the resulting state
  /// ('checked_in' / 'checked_out'), or null.
  Future<String?> _toggle(double latitude, double longitude) async {
    final result = await api.jsonRpc(
      Endpoints.attendanceSystray,
      params: {'latitude': latitude, 'longitude': longitude},
    );
    debugPrint('[Attendance] systray ${Endpoints.attendanceSystray} '
        'raw result (${result.runtimeType}): $result');
    if (result is Map) return result['attendance_state']?.toString();
    return null;
  }

  /// Clocks the current user IN (with GPS) if they aren't already. No-op when
  /// already checked in, so a fresh visit check-in never accidentally clocks
  /// them out. Returns the resulting attendance state, or null when skipped.
  Future<String?> checkIn({
    required double latitude,
    required double longitude,
  }) async {
    final uid = await _uid();
    if (uid == null) return null;
    if (await _hasOpenAttendance(uid)) {
      debugPrint('[Attendance] already checked in — skipping check-in');
      return 'checked_in';
    }
    return _toggle(latitude, longitude);
  }

  /// Clocks the current user OUT (with GPS) if they currently have an open
  /// attendance. No-op otherwise. Returns the resulting state, or null.
  Future<String?> checkOut({
    required double latitude,
    required double longitude,
  }) async {
    final uid = await _uid();
    if (uid == null) return null;
    if (!await _hasOpenAttendance(uid)) {
      debugPrint('[Attendance] no open attendance — skipping check-out');
      return 'checked_out';
    }
    return _toggle(latitude, longitude);
  }
}
