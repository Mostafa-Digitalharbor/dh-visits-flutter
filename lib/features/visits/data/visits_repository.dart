import 'dart:async';

import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import '../../attendance/data/attendance_repository.dart';
import 'mock_location_note.dart';
import 'models/visit.dart';
import 'models/visit_activity.dart';
import 'models/visit_attachment.dart';
import 'models/visit_participant.dart';
import '../../../core/utils/app_log.dart';

// Re-exported so existing importers of this repository keep seeing the marker
// and the phase enum at their original location.
export 'mock_location_note.dart' show kMockLocationMarker, SpoofPhase;

/// Which slice of visits a manager is looking at. Backing domains are applied
/// on top of Odoo record rules (which already scope to the manager's
/// hierarchy), so these only narrow by state.
enum VisitManagerScope { team, pending, escalated }

/// Talks to the `dh_visit_management` Odoo module.
///
/// **Actions** (create / submit / approve / reject / reschedule / start / end /
/// participants / attachments) go through the module's dedicated `/api/visit/*`
/// REST endpoints — they enforce the approval rules and return a slim visit
/// shape ([Visit.fromApi]).
///
/// **Reads that the REST payload doesn't cover** — manager list slices, the
/// rich detail fields (managers, approval history, escalation, start/end GPS),
/// the participant lines, and the project/opportunity pickers — go through
/// `call_kw`. Record rules enforce access server-side either way.
class VisitsRepository {
  final ApiClient api;
  final SessionStorage session;

  /// Optional: mirror Start/End into Odoo `hr.attendance` (best-effort).
  final AttendanceRepository? attendance;

  VisitsRepository({required this.api, required this.session, this.attendance});

  static final DateFormat _odooDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Formats a [DateTime] as Odoo's naive-UTC string (`yyyy-MM-dd HH:mm:ss`).
  static String formatOdooUtc(DateTime dt) =>
      _odooDateTime.format(dt.toUtc());

  // ---------------------------------------------------------------------------
  // REST actions (/api/visit/*)
  // ---------------------------------------------------------------------------

  /// The current user's own visits (server scopes to the caller).
  Future<List<Visit>> myVisits({
    List<dynamic> domain = const [],
    int limit = 80,
    int offset = 0,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitMy,
      params: {'domain': domain, 'limit': limit, 'offset': offset},
    );
    final visits = (result is Map ? result['visits'] : null);
    if (visits is! List) return const [];
    return visits
        .whereType<Map>()
        .map((m) => Visit.fromApi(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Reads one visit via the REST endpoint (slim shape). For the full detail
  /// screen prefer [readVisitFull].
  Future<Visit?> getVisit(int visitId) async {
    final result = await api.jsonRpc(
      Endpoints.visitGet,
      params: {'visit_id': visitId},
    );
    final v = (result is Map ? result['visit'] : null);
    if (v is! Map) return null;
    return Visit.fromApi(Map<String, dynamic>.from(v));
  }

  /// Creates a draft visit. [vals] accepts only the whitelisted keys
  /// (`visit_type`, `project_id`, `opportunity_id`, `scheduled_datetime`,
  /// `purpose`, `location`, `employee_id`, `latitude`, `longitude`).
  Future<Visit> createVisit(Map<String, dynamic> vals) async {
    final result = await api.jsonRpc(
      Endpoints.visitCreate,
      params: {'vals': vals},
    );
    final v = (result is Map ? result['visit'] : null);
    if (v is! Map) {
      throw StateError('create: unexpected response $result');
    }
    return Visit.fromApi(Map<String, dynamic>.from(v));
  }

  Future<String?> submit(int visitId) => _stateAction(Endpoints.visitSubmit, visitId);

  Future<String?> approve(int visitId) =>
      _stateAction(Endpoints.visitApprove, visitId);

  Future<String?> reject(int visitId, String reason) => _stateAction(
        Endpoints.visitReject,
        visitId,
        extra: {'reason': reason},
      );

  Future<String?> reschedule(
    int visitId, {
    DateTime? scheduledDatetime,
    String? purpose,
    String? location,
  }) =>
      _stateAction(Endpoints.visitReschedule, visitId, extra: {
        if (scheduledDatetime != null)
          'scheduled_datetime': formatOdooUtc(scheduledDatetime),
        if (purpose != null) 'purpose': purpose,
        if (location != null) 'location': location,
      });

  /// Adds additional participants; each participant's manager must approve.
  Future<List<VisitParticipant>> addParticipants(
    int visitId,
    List<int> employeeIds,
  ) async {
    final result = await api.jsonRpc(
      Endpoints.visitAddParticipants,
      params: {'visit_id': visitId, 'employee_ids': employeeIds},
    );
    final parts = (result is Map ? result['participants'] : null);
    if (parts is! List) return const [];
    return parts
        .whereType<Map>()
        .map((m) => VisitParticipant.fromApi(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Starts an approved visit (records GPS). Mirrors into `hr.attendance`.
  ///
  /// [isMocked] is the OS mock-provider verdict. See [_recordSpoofAttempt] for
  /// why it is posted to the chatter rather than written to a field.
  Future<String?> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitStart,
      params: {
        'visit_id': visitId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (location != null) 'location': location,
      },
    );
    if (isMocked) {
      await _recordSpoofAttempt(visitId,
          phase: SpoofPhase.start,
          latitude: latitude,
          longitude: longitude,
          location: location);
    }
    if (latitude != null && longitude != null) {
      try {
        await attendance?.checkIn(latitude: latitude, longitude: longitude);
      } catch (e) {
        appLog('[VisitsRepository] attendance check-in failed: $e');
      }
    }
    return (result is Map ? result['state']?.toString() : null);
  }

  /// Ends an in-progress visit (outcome required, records GPS). Mirrors into
  /// `hr.attendance`.
  Future<String?> end(
    int visitId, {
    required String outcome,
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitEnd,
      params: {
        'visit_id': visitId,
        'outcome': outcome,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (location != null) 'location': location,
      },
    );
    if (isMocked) {
      await _recordSpoofAttempt(visitId,
          phase: SpoofPhase.end,
          latitude: latitude,
          longitude: longitude,
          location: location);
    }
    if (latitude != null && longitude != null) {
      try {
        await attendance?.checkOut(latitude: latitude, longitude: longitude);
      } catch (e) {
        appLog('[VisitsRepository] attendance check-out failed: $e');
      }
    }
    return (result is Map ? result['state']?.toString() : null);
  }

  /// Writes a mock-location verdict onto the visit's chatter, permanently and
  /// visibly to any manager reviewing the record in Odoo. The wording itself
  /// lives in [MockLocationNote].
  ///
  /// **Why the chatter and not a field.** `dh.visit` has no `is_mocked` column
  /// and adding one needs the backend team, who as of 2026-07-16 still have not
  /// delivered four earlier asks (the FCM service account, the `/api/visit/my`
  /// creator-filter bug, coordinates on the REST payload, `crm.lead` access).
  /// Sequencing our only category-unique control behind that queue would leave
  /// it dead indefinitely. `message_post` needs no schema change, no module
  /// release and no ticket — and writing location evidence into the chatter is
  /// what Odoo's own Field Service does, so this is the idiomatic pattern, not
  /// a workaround. A real indexed boolean stays the right long-term fix: it is
  /// what makes the signal *filterable* and *exportable*, which chatter is not.
  ///
  /// Best-effort: a failure here must never block or reverse a visit action
  /// that the server already accepted. Sentry keeps the developer-visible copy
  /// so a silently failing post is still detectable.
  Future<void> _recordSpoofAttempt(
    int visitId, {
    required SpoofPhase phase,
    double? latitude,
    double? longitude,
    String? location,
  }) async {
    final note = MockLocationNote.build(
      phase: phase,
      latitude: latitude,
      longitude: longitude,
      location: location,
    );

    try {
      final posted = await api.callMethod(
        AppConstants.visitModel,
        'message_post',
        args: [
          [visitId]
        ],
        kwargs: {
          'body': note.plain,
          'message_type': 'comment',
          // 'comment' + this subtype is what makes Odoo notify the record's
          // followers (the manager is one) rather than filing a silent log.
          // Verified live: posting this way notifies both Sam and Mona.
          'subtype_xmlid': 'mail.mt_comment',
        },
      );
      final messageId = posted is List && posted.isNotEmpty
          ? posted.first
          : (posted is num ? posted : null);
      if (messageId is num) {
        // Formatting only — the note above is already complete without it.
        try {
          await api.writeRecord(
            'mail.message',
            [messageId.toInt()],
            {'body': note.html},
          );
        } catch (e) {
          appLog('[VisitsRepository] spoof-note markup upgrade failed: $e');
        }
      }
    } catch (e) {
      // Most likely cause is `_mail_post_access` requiring write permission the
      // field employee does not have on their own visit. Losing the note must
      // not lose the visit, but we must know it happened.
      appLog('[VisitsRepository] spoof-attempt note failed: $e');
      unawaited(Sentry.captureException(
        e,
        stackTrace: StackTrace.current,
        withScope: (scope) => scope.setContexts('mock_location', {
          'visit_id': visitId,
          'phase': phase.name,
          'coordinates': MockLocationNote.formatCoords(latitude, longitude),
        }),
      ));
    }
  }

  /// Uploads a base64-encoded attachment to a visit. Returns the attachment id.
  Future<int?> uploadAttachment(
    int visitId, {
    required String filename,
    required String dataB64,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitUploadAttachment,
      params: {
        'visit_id': visitId,
        'filename': filename,
        'data_b64': dataB64,
      },
    );
    return (result is Map ? (result['attachment_id'] as num?)?.toInt() : null);
  }

  Future<String?> _stateAction(
    String path,
    int visitId, {
    Map<String, dynamic> extra = const {},
  }) async {
    final result = await api.jsonRpc(
      path,
      params: {'visit_id': visitId, ...extra},
    );
    return (result is Map ? result['state']?.toString() : null);
  }

  // ---------------------------------------------------------------------------
  // call_kw reads / actions not exposed by the REST API
  // ---------------------------------------------------------------------------

  /// Manager list slices. Record rules restrict rows to the manager's
  /// hierarchy; [scope] narrows further by state.
  Future<List<Visit>> managerList(
    VisitManagerScope scope, {
    int limit = 200,
  }) async {
    final domain = <dynamic>[];
    switch (scope) {
      case VisitManagerScope.pending:
        domain.add([
          'state',
          'in',
          [
            // The current backend uses `submitted` as the single
            // pending-approval state; the `waiting_*` states are kept for
            // forward-compatibility.
            'submitted',
            'waiting_participant_manager_approval',
            'waiting_direct_manager_approval',
            'reschedule_requested',
          ],
        ]);
        break;
      case VisitManagerScope.escalated:
        // The current backend flags escalation with `is_escalated=True` while
        // keeping the visit in its pending state (rather than a dedicated
        // `escalated` state), so filter on the flag.
        domain.add(['is_escalated', '=', true]);
        break;
      case VisitManagerScope.team:
        break; // everything visible to this manager
    }
    final rows = await api.searchRead(
      AppConstants.visitModel,
      domain: domain,
      fields: Visit.odooReadFields,
      limit: limit,
      order: 'scheduled_datetime desc, id desc',
    );
    return rows.map((r) => Visit.fromOdooRow(r)).toList();
  }

  /// Full detail read (rich fields + participant lines).
  Future<Visit?> readVisitFull(int visitId) async {
    final rows = await api.readRecords(
      AppConstants.visitModel,
      [visitId],
      Visit.odooReadFields,
    );
    if (rows.isEmpty) return null;
    final participants = await readParticipants(visitId);
    return Visit.fromOdooRow(
      rows.first,
      participants: participants,
    );
  }

  /// Whether a mock-location verdict was ever recorded against this visit.
  ///
  /// Reads the chatter rather than a field because that is where the verdict
  /// lives — see [_recordSpoofAttempt]. Scoped to one visit and only called
  /// from the detail page, so it stays a single cheap query; do NOT call this
  /// per row of a list, which would be one round trip per visit.
  ///
  /// Returns false on any failure: a warning banner that fails to appear is a
  /// missed flag, but an exception here would take down a detail page that
  /// otherwise loaded fine.
  Future<bool> hasMockLocationFlag(int visitId) async {
    try {
      final rows = await api.searchRead(
        'mail.message',
        domain: [
          ['model', '=', AppConstants.visitModel],
          ['res_id', '=', visitId],
          ['body', 'ilike', kMockLocationMarker],
        ],
        fields: const ['id'],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      appLog('[VisitsRepository] mock-flag lookup failed: $e');
      return false;
    }
  }

  Future<List<VisitParticipant>> readParticipants(int visitId) async {
    final rows = await api.searchRead(
      AppConstants.visitParticipantModel,
      domain: [
        ['visit_id', '=', visitId],
      ],
      fields: const [
        'id',
        'employee_id',
        'manager_id',
        'approval_state',
        'reject_reason',
      ],
    );
    return rows.map((r) => VisitParticipant.fromOdooRow(r)).toList();
  }

  /// Participant-manager approves one participant line (`action_approve`).
  Future<void> approveParticipant(int participantId) async {
    await _participantAction('action_approve', participantId);
  }

  /// Participant-manager rejects one participant line. The reason is written to
  /// the line first, then `action_reject` is invoked (which reads it / triggers
  /// the configured rejection policy). Writing the reason is best-effort in
  /// case record rules only allow the action method.
  Future<void> rejectParticipant(int participantId, String reason) async {
    try {
      await api.writeRecord(
        AppConstants.visitParticipantModel,
        [participantId],
        {'reject_reason': reason},
      );
    } catch (e) {
      appLog('[VisitsRepository] participant reason write failed: $e');
    }
    await _participantAction('action_reject', participantId);
  }

  Future<void> _participantAction(String method, int participantId) async {
    await api.callMethod(
      AppConstants.visitParticipantModel,
      method,
      args: [
        [participantId],
      ],
    );
  }

  /// Owner/manager cancels a visit (`action_cancel`; not in the REST API).
  Future<void> cancel(int visitId) => _visitAction('action_cancel', visitId);

  Future<void> _visitAction(String method, int visitId) async {
    await api.callMethod(
      AppConstants.visitModel,
      method,
      args: [
        [visitId],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Attachments (ir.attachment linked via res_model/res_id)
  // ---------------------------------------------------------------------------

  Future<List<VisitAttachment>> readAttachments(int visitId) async {
    final rows = await api.searchRead(
      AppConstants.attachmentModel,
      domain: [
        ['res_model', '=', AppConstants.visitModel],
        ['res_id', '=', visitId],
      ],
      fields: const ['id', 'name', 'mimetype', 'file_size'],
      order: 'create_date desc',
    );
    return rows.map((r) => VisitAttachment.fromJson(r)).toList();
  }

  /// Returns the base64-encoded bytes of an attachment (`ir.attachment.datas`).
  Future<String?> downloadAttachmentB64(int attachmentId) async {
    final rows = await api.readRecords(
      AppConstants.attachmentModel,
      [attachmentId],
      const ['datas'],
    );
    if (rows.isEmpty) return null;
    final datas = rows.first['datas'];
    return (datas == null || datas == false) ? null : datas.toString();
  }

  // ---------------------------------------------------------------------------
  // In-app notifications (mail.activity assigned to the current user)
  // ---------------------------------------------------------------------------

  Future<int?> _currentUid() async {
    final u = await session.getUser();
    return (u?['uid'] as num?)?.toInt();
  }

  /// The current user's pending activities on visits (approve / escalated /
  /// participant approvals) — the in-app notification feed.
  Future<List<VisitActivity>> myActivities() async {
    final uid = await _currentUid();
    if (uid == null) return const [];
    final rows = await api.searchRead(
      AppConstants.mailActivityModel,
      domain: [
        ['user_id', '=', uid],
        ['res_model', '=', AppConstants.visitModel],
      ],
      fields: const [
        'id',
        'summary',
        'activity_type_id',
        'res_id',
        'res_name',
        'date_deadline',
        'state',
      ],
      limit: AppConstants.visitRelatedLimit,
      order: 'date_deadline asc',
    );
    return rows.map((r) => VisitActivity.fromJson(r)).toList();
  }

  Future<int> myActivityCount() async {
    final uid = await _currentUid();
    if (uid == null) return 0;
    return api.searchCount(
      AppConstants.mailActivityModel,
      domain: [
        ['user_id', '=', uid],
        ['res_model', '=', AppConstants.visitModel],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Customer geolocation (for the visit-detail map)
  // ---------------------------------------------------------------------------

  /// Reads the customer's office coordinates (+ address / phone) straight from
  /// `res.partner` (`base_geolocalize` fields). Used to centre the geofence map
  /// on the visit-detail page and to power the "Directions" hand-off. Returns
  /// `null` when the partner has no coordinates (Odoo stores 0.0 for unset) or
  /// the read is not permitted — the map degrades gracefully to the GPS points.
  Future<PartnerLocation?> partnerLocation(int partnerId) async {
    try {
      final rows = await api.readRecords(
        AppConstants.partnerModel,
        [partnerId],
        const ['partner_latitude', 'partner_longitude', 'contact_address', 'phone'],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      double? coord(dynamic raw) {
        if (raw is! num) return null;
        final v = raw.toDouble();
        return v == 0.0 ? null : v;
      }

      String? str(dynamic raw) {
        if (raw == null || raw == false) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      }

      final lat = coord(row['partner_latitude']);
      final lng = coord(row['partner_longitude']);
      if (lat == null || lng == null) return null;
      return PartnerLocation(
        latitude: lat,
        longitude: lng,
        address: str(row['contact_address']),
        phone: str(row['phone']),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pickers for the create form
  // ---------------------------------------------------------------------------

  /// Projects (with their customer) for the project-visit picker.
  Future<List<LinkedRecord>> listProjects() =>
      _listLinked(AppConstants.projectModel, const []);

  /// Opportunities (with their customer) for the opportunity-visit picker.
  Future<List<LinkedRecord>> listOpportunities() => _listLinked(
        AppConstants.crmLeadModel,
        const [
          ['type', '=', 'opportunity'],
        ],
      );

  Future<List<LinkedRecord>> _listLinked(
    String model,
    List<dynamic> domain,
  ) async {
    final rows = await api.searchRead(
      model,
      domain: domain,
      fields: const ['id', 'name', 'partner_id'],
      limit: AppConstants.visitsAnalyticsLimit,
      order: 'name asc',
    );
    return rows.map((row) {
      int? pid;
      String? pname;
      final p = row['partner_id'];
      if (p is List && p.length >= 2) {
        pid = (p[0] as num?)?.toInt();
        pname = p[1]?.toString();
      }
      return LinkedRecord(
        id: (row['id'] as num).toInt(),
        name: row['name']?.toString() ?? '',
        partnerId: pid,
        partnerName: pname,
      );
    }).toList();
  }
}

/// A project or opportunity option in the create-visit picker, carrying the
/// customer it will auto-fill.
class LinkedRecord {
  final int id;
  final String name;
  final int? partnerId;
  final String? partnerName;

  const LinkedRecord({
    required this.id,
    required this.name,
    this.partnerId,
    this.partnerName,
  });
}

/// The customer office coordinates (+ address / phone) read from `res.partner`
/// for the visit-detail geofence map and "Directions" hand-off.
class PartnerLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;

  const PartnerLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });
}
