import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/constants.dart';
import '../../../core/storage/session_storage.dart';
import '../../attendance/data/attendance_repository.dart';
import 'models/visit.dart';
import 'models/visit_participant.dart';

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
  Future<String?> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
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
    if (latitude != null && longitude != null) {
      try {
        await attendance?.checkIn(latitude: latitude, longitude: longitude);
      } catch (e) {
        debugPrint('[VisitsRepository] attendance check-in failed: $e');
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
    if (latitude != null && longitude != null) {
      try {
        await attendance?.checkOut(latitude: latitude, longitude: longitude);
      } catch (e) {
        debugPrint('[VisitsRepository] attendance check-out failed: $e');
      }
    }
    return (result is Map ? result['state']?.toString() : null);
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
            'waiting_participant_manager_approval',
            'waiting_direct_manager_approval',
            'reschedule_requested',
          ],
        ]);
        break;
      case VisitManagerScope.escalated:
        domain.add(['state', '=', 'escalated']);
        break;
      case VisitManagerScope.team:
        break; // everything visible to this manager
    }
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'search_read',
        'args': [domain, Visit.odooReadFields],
        'kwargs': {
          'limit': limit,
          'order': 'scheduled_datetime desc, id desc',
        },
      },
    );
    final rows = result is List ? result : const [];
    return rows
        .whereType<Map>()
        .map((r) => Visit.fromOdooRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Full detail read (rich fields + participant lines).
  Future<Visit?> readVisitFull(int visitId) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': 'read',
        'args': [
          [visitId],
          Visit.odooReadFields,
        ],
        'kwargs': {},
      },
    );
    final rows = result is List ? result : const [];
    if (rows.isEmpty || rows.first is! Map) return null;
    final participants = await readParticipants(visitId);
    return Visit.fromOdooRow(
      Map<String, dynamic>.from(rows.first as Map),
      participants: participants,
    );
  }

  Future<List<VisitParticipant>> readParticipants(int visitId) async {
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitParticipantModel,
        'method': 'search_read',
        'args': [
          [
            ['visit_id', '=', visitId],
          ],
          ['id', 'employee_id', 'manager_id', 'approval_state', 'reject_reason'],
        ],
        'kwargs': {},
      },
    );
    final rows = result is List ? result : const [];
    return rows
        .whereType<Map>()
        .map((r) => VisitParticipant.fromOdooRow(Map<String, dynamic>.from(r)))
        .toList();
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
      await api.jsonRpc(
        Endpoints.callKw,
        params: {
          'model': AppConstants.visitParticipantModel,
          'method': 'write',
          'args': [
            [participantId],
            {'reject_reason': reason},
          ],
          'kwargs': {},
        },
      );
    } catch (e) {
      debugPrint('[VisitsRepository] participant reason write failed: $e');
    }
    await _participantAction('action_reject', participantId);
  }

  Future<void> _participantAction(String method, int participantId) async {
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitParticipantModel,
        'method': method,
        'args': [
          [participantId],
        ],
        'kwargs': {},
      },
    );
  }

  /// Owner/manager cancels a visit (`action_cancel`; not in the REST API).
  Future<void> cancel(int visitId) => _visitAction('action_cancel', visitId);

  /// Sends a visit back to draft (`action_reset_to_draft`).
  Future<void> resetToDraft(int visitId) =>
      _visitAction('action_reset_to_draft', visitId);

  Future<void> _visitAction(String method, int visitId) async {
    await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': AppConstants.visitModel,
        'method': method,
        'args': [
          [visitId],
        ],
        'kwargs': {},
      },
    );
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
    final result = await api.jsonRpc(
      Endpoints.callKw,
      params: {
        'model': model,
        'method': 'search_read',
        'args': [domain, ['id', 'name', 'partner_id']],
        'kwargs': {'order': 'name asc', 'limit': 500},
      },
    );
    final rows = result is List ? result : const [];
    return rows.whereType<Map>().map((r) {
      final row = Map<String, dynamic>.from(r);
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
