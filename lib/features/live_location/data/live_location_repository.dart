import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';

/// Live employee location, stored on a **standard** `calendar.event` — no
/// custom Odoo module needed.
///
/// Each employee owns a single "presence" event (their own record, so writing
/// it needs no special rights) tagged with [presenceMarker] in the
/// description. The current GPS fix is packed as base64-encoded JSON inside
/// that description and refreshed on every ping. Managers read all presence
/// events back via [NearbyRepository] to populate the radar.
class LiveLocationRepository {
  final ApiClient api;
  final SessionStorage session;

  LiveLocationRepository({required this.api, required this.session});

  static final DateFormat _odooDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Fenced markers around the base64 payload (see [VisitsRepository] for the
  /// matching scheme used by visits). Kept distinct from the visit marker so
  /// presence records never show up in the visits list and vice-versa.
  static const String presenceMarker = '⟦presence⟧';
  static const String _markerEnd = '⟦/presence⟧';

  bool get isSupported => true;

  static String encodeDescription(Map<String, dynamic> meta) {
    final payload = base64.encode(utf8.encode(jsonEncode(meta)));
    return '$presenceMarker$payload$_markerEnd';
  }

  /// Decodes a presence description back into its meta map (empty if the
  /// markers are missing or the payload is corrupt).
  static Map<String, dynamic> decodeDescription(dynamic raw) {
    final text = (raw == null || raw == false) ? '' : raw.toString();
    final start = text.indexOf(presenceMarker);
    final end = text.indexOf(_markerEnd);
    if (start == -1 || end == -1 || end <= start) return <String, dynamic>{};
    final payload = text.substring(start + presenceMarker.length, end);
    try {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(base64.decode(payload))) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> push({
    required double latitude,
    required double longitude,
    double? accuracy,
    DateTime? timestamp,
  }) async {
    final user = await session.getUser();
    final uid = (user?['uid'] as num?)?.toInt();
    if (uid == null) return; // not logged in — nothing to attribute the ping to
    final name = (user?['employee_name'] ?? user?['username'] ?? 'Employee')
        .toString();
    final now = (timestamp ?? DateTime.now().toUtc()).toUtc();

    final meta = <String, dynamic>{
      'p': 1,
      'lat': latitude,
      'lng': longitude,
      't': now.toIso8601String(),
      if (accuracy != null) 'acc': accuracy,
    };
    final description = encodeDescription(meta);

    // Find this user's existing presence record.
    final existing = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.calendarEventModel,
        'method': 'search',
        'args': [
          [
            ['user_id', '=', uid],
            ['description', 'like', presenceMarker],
          ],
        ],
        'kwargs': {'limit': 1},
      },
    );
    final ids = existing is List ? existing : <dynamic>[];

    if (ids.isNotEmpty) {
      await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.calendarEventModel,
          'method': 'write',
          'args': [
            [ (ids.first as num).toInt() ],
            {'description': description},
          ],
          'kwargs': {},
        },
      );
    } else {
      await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.calendarEventModel,
          'method': 'create',
          'args': [
            {
              'name': '📍 $name',
              'start': _odooDateTime.format(now),
              'stop': _odooDateTime.format(now.add(const Duration(hours: 1))),
              'user_id': uid,
              'description': description,
            },
          ],
          'kwargs': {},
        },
      );
    }
  }
}
