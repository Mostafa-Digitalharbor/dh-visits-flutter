import 'dart:async';

import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_parse.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../../core/network/server_clock.dart';
import '../../../core/storage/session_storage.dart';
import '../visit_constants.dart';
import 'mock_location_note.dart';
import 'models/visit.dart';
import 'models/visit_activity.dart';
import 'models/visit_attachment.dart';
import 'models/visit_location_log.dart';
import 'models/visit_participant.dart';
import '../../../core/utils/app_log.dart';

// Re-exported so existing importers of this repository keep seeing the marker
// and the phase enum at their original location.
export 'mock_location_note.dart' show kMockLocationMarker, SpoofPhase;

/// The server's answer to Start / End: the visit's resulting state and the
/// moment the server stamped for the transition (`start_datetime` /
/// `end_datetime`, server clock, UTC). Either may be null when the response
/// leaves it out.
typedef VisitTransition = ({VisitState? state, DateTime? at});

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

  /// The server's clock. The server judges a fix's `logged_at` against its own
  /// time, so a default "now" must be read off this rather than the device
  /// clock: a phone running 90 s fast otherwise files a point after the end
  /// of a visit that is still running (measured live on 2026-09-17).
  final ServerClock? serverClock;

  VisitsRepository({
    required this.api,
    required this.session,
    this.serverClock,
  });

  // Odoo names this repository calls by string. Each is used only here.
  static const _messagePost = 'message_post';
  static const _messageTypeComment = 'comment';

  /// The subtype that makes a chatter post notify the record's followers.
  static const _commentSubtype = 'mail.mt_comment';
  static const _actionApprove = 'action_approve';
  static const _actionReject = 'action_reject';
  static const _actionCancel = 'action_cancel';

  /// `crm.lead` rows that are opportunities rather than leads.
  static const _opportunityType = 'opportunity';

  /// States a manager's "pending" tab lists. The current backend uses
  /// `submitted` as the single pending-approval state; the `waiting_*` states
  /// are kept for forward-compatibility.
  static const _pendingStates = [
    VisitState.submitted,
    VisitState.waitingParticipantManagerApproval,
    VisitState.waitingDirectManagerApproval,
    VisitState.rescheduleRequested,
  ];

  // Locale pinned: a bare `DateFormat` follows `Intl.defaultLocale`, and under
  // an Arabic locale intl emits Arabic-Indic digits ("٢٠٢٦-٠٩-١٢ …"), which the
  // server refuses as "not a valid date and time". This is a wire format, not
  // a display string.
  static final DateFormat _odooDateTime = DateFormat(
    'yyyy-MM-dd HH:mm:ss',
    'en_US',
  );

  /// Formats a [DateTime] as Odoo's naive-UTC string (`yyyy-MM-dd HH:mm:ss`).
  static String formatOdooUtc(DateTime dt) => _odooDateTime.format(dt.toUtc());

  // ---------------------------------------------------------------------------
  // REST actions (/api/visit/*)
  // ---------------------------------------------------------------------------

  /// The current user's own visits (server scopes to the caller).
  Future<List<Visit>> myVisits({
    List<dynamic> domain = const [],
    int limit = AppConstants.visitsPageLimit,
    int offset = 0,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitMy,
      params: {'domain': domain, 'limit': limit, 'offset': offset},
    );
    return parseRows(
      odooMap(result)?['visits'],
      Visit.fromApi,
      label: 'VisitsRepository.myVisits',
    );
  }

  /// The caller's visit that is running right now, if any.
  Future<Visit?> myRunningVisit() async {
    final running = await myVisits(
      domain: [
        ['state', '=', visitStateToWire(VisitState.inProgress)],
      ],
      limit: 1,
    );
    return running.isEmpty ? null : running.first;
  }

  /// Reads one visit via the REST endpoint (slim shape). For the full detail
  /// screen prefer [readVisitFull].
  Future<Visit?> getVisit(int visitId) async {
    final result = await api.jsonRpc(
      Endpoints.visitGet,
      params: {'visit_id': visitId},
    );
    final v = odooMap(odooMap(result)?['visit']);
    return v == null ? null : Visit.fromApi(v);
  }

  /// Creates a draft visit. [vals] accepts only the whitelisted keys
  /// (`visit_type`, `project_id`, `opportunity_id`, `scheduled_datetime`,
  /// `purpose`, `location`, `employee_id`, `latitude`, `longitude`).
  Future<Visit> createVisit(Map<String, dynamic> vals) async {
    final result = await api.jsonRpc(
      Endpoints.visitCreate,
      params: {'vals': vals},
    );
    final v = odooMap(odooMap(result)?['visit']);
    if (v == null) {
      // The server may well have created the visit; the caller must not treat
      // this as "nothing happened" and retry blindly.
      throw ApiException(
        code: ApiErrorCode.invalidResponse,
        details: 'visit/create returned no visit: $result',
      );
    }
    try {
      return Visit.fromApi(v);
    } on FormatException catch (e) {
      throw ApiException(code: ApiErrorCode.invalidResponse, details: e);
    }
  }

  Future<String?> submit(int visitId) =>
      _stateAction(Endpoints.visitSubmit, visitId);

  Future<String?> approve(int visitId) =>
      _stateAction(Endpoints.visitApprove, visitId);

  Future<String?> reject(int visitId, String reason) =>
      _stateAction(Endpoints.visitReject, visitId, extra: {'reason': reason});

  Future<String?> reschedule(
    int visitId, {
    DateTime? scheduledDatetime,
    String? purpose,
    String? location,
  }) => _stateAction(
    Endpoints.visitReschedule,
    visitId,
    extra: {
      if (scheduledDatetime != null)
        'scheduled_datetime': formatOdooUtc(scheduledDatetime),
      if (purpose != null) 'purpose': purpose,
      if (location != null) 'location': location,
    },
  );

  /// Adds additional participants; each participant's manager must approve.
  Future<List<VisitParticipant>> addParticipants(
    int visitId,
    List<int> employeeIds,
  ) async {
    final result = await api.jsonRpc(
      Endpoints.visitAddParticipants,
      params: {'visit_id': visitId, 'employee_ids': employeeIds},
    );
    return parseRows(
      odooMap(result)?['participants'],
      VisitParticipant.fromApi,
      label: 'VisitsRepository.addParticipants',
    );
  }

  /// Starts an approved visit. The coordinates become the first point of its
  /// GPS trail (`source: start`).
  ///
  /// [isMocked] is the OS mock-provider verdict. See [_recordSpoofAttempt] for
  /// why it is posted to the chatter rather than written to a field.
  Future<VisitTransition> start(
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
      await _recordSpoofAttempt(
        visitId,
        phase: SpoofPhase.start,
        latitude: latitude,
        longitude: longitude,
        location: location,
      );
    }
    return _transition(result, 'start_datetime');
  }

  /// Ends an in-progress visit (outcome required). The coordinates become the
  /// last point of its GPS trail (`source: end`).
  Future<VisitTransition> end(
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
      await _recordSpoofAttempt(
        visitId,
        phase: SpoofPhase.end,
        latitude: latitude,
        longitude: longitude,
        location: location,
      );
    }
    return _transition(result, 'end_datetime');
  }

  static VisitTransition _transition(Object? result, String timeField) {
    final body = odooMap(result);
    final state = odooString(body?['state']);
    return (
      state: state == null ? null : visitStateFromWire(state),
      at: parseOdooUtc(body?[timeField]),
    );
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
        _messagePost,
        args: [
          [visitId],
        ],
        kwargs: {
          'body': note.plain,
          'message_type': _messageTypeComment,
          // 'comment' + this subtype is what makes Odoo notify the record's
          // followers (the manager is one) rather than filing a silent log.
          // Verified live: posting this way notifies both Sam and Mona.
          'subtype_xmlid': _commentSubtype,
        },
      );
      final messageId = posted is List && posted.isNotEmpty
          ? odooInt(posted.first)
          : odooInt(posted);
      if (messageId != null) {
        // Formatting only — the note above is already complete without it.
        try {
          await api.writeRecord(
            AppConstants.mailMessageModel,
            [messageId],
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
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: StackTrace.current,
          withScope: (scope) => scope.setContexts('mock_location', {
            'visit_id': visitId,
            'phase': phase.name,
            'coordinates': MockLocationNote.formatCoords(latitude, longitude),
          }),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GPS trail (/api/visit/log_location · log_locations · track)
  // ---------------------------------------------------------------------------

  /// Reads a visit's trail, oldest fix first — ready to feed straight into a
  /// polyline.
  ///
  /// [limit]/[offset] page the points and [dateFrom]/[dateTo] window them; with
  /// none of them the whole trail comes back. The counters on [VisitTrack]
  /// always describe the *full* trail even when the points are a slice.
  Future<VisitTrack> readTrack(
    int visitId, {
    int? limit,
    int offset = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitTrack,
      params: {
        'visit_id': visitId,
        if (limit != null) 'limit': limit,
        if (offset > 0) 'offset': offset,
        if (dateFrom != null) 'date_from': formatOdooUtc(dateFrom),
        if (dateTo != null) 'date_to': formatOdooUtc(dateTo),
      },
    );
    final body = odooMap(result);
    return body == null
        ? VisitTrack(visitId: visitId)
        : VisitTrack.fromApi(body);
  }

  /// Appends a single fix to the trail.
  ///
  /// Prefer [logLocations] for anything the tracker collects: one round trip
  /// per fix is wasteful on a field connection, and a batch reports bad points
  /// individually instead of failing whole. This exists for the one-off case
  /// (a manual "record my position" tap) and as the fallback when a batch of
  /// one is all there is.
  Future<VisitLocationLog?> logLocation(
    int visitId, {
    required double latitude,
    required double longitude,
    DateTime? loggedAt,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    String? location,
    String? deviceId,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitLogLocation,
      params: {
        'visit_id': visitId,
        'latitude': latitude,
        'longitude': longitude,
        // Always sent, never left to the server's "now" default: a fix that
        // waited out a dead zone has to keep the time it was actually taken or
        // it lands in the wrong place in the path.
        'logged_at': formatOdooUtc(
          loggedAt ?? serverClock?.now() ?? DateTime.now(),
        ),
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (location != null) 'location': location,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
    final log = odooMap(odooMap(result)?['log']);
    return log == null ? null : VisitLocationLog.tryFromApi(log);
  }

  /// Flushes a buffer of fixes in one round trip.
  ///
  /// Points may be sent in any order — the server files them by `logged_at`.
  /// A malformed point is refused on its own and reported in
  /// [TrailFlushResult.rejected] by its index in [points], so one bad fix never
  /// costs the caller the rest of its queue.
  Future<TrailFlushResult> logLocations(
    int visitId,
    List<TrailPoint> points,
  ) async {
    if (points.isEmpty) return const TrailFlushResult();
    final result = await api.jsonRpc(
      Endpoints.visitLogLocations,
      params: {
        'visit_id': visitId,
        'points': [for (final p in points) p.toApi(formatUtc: formatOdooUtc)],
      },
    );
    final body = odooMap(result);
    return body == null
        ? const TrailFlushResult()
        : TrailFlushResult.fromApi(body);
  }

  /// Uploads a base64-encoded attachment to a visit. Returns the attachment id.
  Future<int?> uploadAttachment(
    int visitId, {
    required String filename,
    required String dataB64,
  }) async {
    final result = await api.jsonRpc(
      Endpoints.visitUploadAttachment,
      params: {'visit_id': visitId, 'filename': filename, 'data_b64': dataB64},
    );
    return odooInt(odooMap(result)?['attachment_id']);
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
    return odooString(odooMap(result)?['state']);
  }

  // ---------------------------------------------------------------------------
  // call_kw reads / actions not exposed by the REST API
  // ---------------------------------------------------------------------------

  /// Manager list slices. Record rules restrict rows to the manager's
  /// hierarchy; [scope] narrows further by state.
  Future<List<Visit>> managerList(
    VisitManagerScope scope, {
    int limit = AppConstants.visitsPageLimit,
  }) async {
    final domain = <dynamic>[];
    switch (scope) {
      case VisitManagerScope.pending:
        domain.add([
          'state',
          'in',
          [for (final state in _pendingStates) visitStateToWire(state)],
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
    return parseRows(
      rows,
      (row) => Visit.fromOdooRow(row),
      label: 'VisitsRepository.managerList',
    );
  }

  /// Full detail read (rich fields + participant lines).
  Future<Visit?> readVisitFull(int visitId) async {
    final rows = await api.readRecords(AppConstants.visitModel, [
      visitId,
    ], Visit.odooReadFields);
    if (rows.isEmpty) return null;
    final participants = await readParticipants(visitId);
    try {
      return Visit.fromOdooRow(rows.first, participants: participants);
    } on FormatException catch (e) {
      throw ApiException(code: ApiErrorCode.invalidResponse, details: e);
    }
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
        AppConstants.mailMessageModel,
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
    return parseRows(
      rows,
      VisitParticipant.fromOdooRow,
      label: 'VisitsRepository.readParticipants',
    );
  }

  /// Participant-manager approves one attendee line (approval track 2).
  ///
  /// Goes through `/api/visit/attendee/approve` where the server has it, since
  /// that route is what enforces "nobody approves their own participation" and
  /// returns the visit's resulting state. Falls back to `action_approve` over
  /// `call_kw` — the path this app used before the module exposed the route —
  /// so a company still on an older `dh_visit_management` keeps working.
  Future<void> approveParticipant(int participantId) => _attendeeDecision(
    Endpoints.visitAttendeeApprove,
    _actionApprove,
    participantId,
  );

  /// Participant-manager rejects one attendee line. The reason travels with the
  /// call; on the `call_kw` fallback it has to be written to the line first
  /// (best-effort, in case record rules only allow the action method) because
  /// `action_reject` reads it back off the record.
  ///
  /// The visit's own state afterwards follows the server's *Participant
  /// Rejection Policy* setting — `draft` by default, or `rejected`.
  Future<void> rejectParticipant(int participantId, String reason) =>
      _attendeeDecision(
        Endpoints.visitAttendeeReject,
        _actionReject,
        participantId,
        extra: {'reason': reason},
        beforeFallback: () async {
          try {
            await api.writeRecord(
              AppConstants.visitParticipantModel,
              [participantId],
              {'reject_reason': reason},
            );
          } catch (e) {
            appLog('[VisitsRepository] participant reason write failed: $e');
          }
        },
      );

  /// Runs an attendee decision over REST, degrading to `call_kw` only when the
  /// route is missing from this server.
  ///
  /// The fallback is deliberately narrow: [ApiErrorCode.notSupported] is what
  /// `ApiClient` raises for a route Odoo has no controller for. A `UserError`
  /// ("you cannot approve your own participation") or an `AccessError` is a
  /// real verdict that must reach the user — retrying it through `call_kw`
  /// would either fail again with a worse message or, worse, succeed and route
  /// around the rule the endpoint exists to enforce.
  Future<void> _attendeeDecision(
    String path,
    String fallbackMethod,
    int participantId, {
    Map<String, dynamic> extra = const {},
    Future<void> Function()? beforeFallback,
  }) async {
    try {
      await api.jsonRpc(
        path,
        params: {'participant_id': participantId, ...extra},
      );
      return;
    } on ApiException catch (e) {
      if (e.code != ApiErrorCode.notSupported) rethrow;
      appLog(
        '[VisitsRepository] $path not deployed; '
        'falling back to $fallbackMethod',
      );
    }
    await beforeFallback?.call();
    await _participantAction(fallbackMethod, participantId);
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
  Future<void> cancel(int visitId) => _visitAction(_actionCancel, visitId);

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
    return parseRows(
      rows,
      VisitAttachment.fromJson,
      label: 'VisitsRepository.readAttachments',
    );
  }

  /// Returns the base64-encoded bytes of an attachment (`ir.attachment.datas`).
  Future<String?> downloadAttachmentB64(int attachmentId) async {
    final rows = await api.readRecords(
      AppConstants.attachmentModel,
      [attachmentId],
      const ['datas'],
    );
    if (rows.isEmpty) return null;
    return odooString(rows.first['datas']);
  }

  // ---------------------------------------------------------------------------
  // In-app notifications (mail.activity assigned to the current user)
  // ---------------------------------------------------------------------------

  /// The current user's pending activities on visits (approve / escalated /
  /// participant approvals) — the in-app notification feed.
  Future<List<VisitActivity>> myActivities() async {
    final uid = await session.readUid();
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
    return parseRows(
      rows,
      VisitActivity.fromJson,
      label: 'VisitsRepository.myActivities',
    );
  }

  Future<int> myActivityCount() async {
    final uid = await session.readUid();
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
        const [
          'partner_latitude',
          'partner_longitude',
          'contact_address',
          'phone',
        ],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final lat = odooCoord(row['partner_latitude']);
      final lng = odooCoord(row['partner_longitude']);
      if (lat == null || lng == null || !isValidLatLng(lat, lng)) return null;
      return PartnerLocation(
        latitude: lat,
        longitude: lng,
        address: odooString(row['contact_address']),
        phone: odooString(row['phone']),
      );
    } catch (e) {
      appLog('[VisitsRepository] partner location unavailable: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pickers for the create form
  // ---------------------------------------------------------------------------

  /// Projects (with their customer) for the project-visit picker, matching
  /// [search] on the server.
  Future<List<LinkedRecord>> listProjects({String? search}) =>
      _listLinked(AppConstants.projectModel, const [], search);

  /// Opportunities (with their customer) for the opportunity-visit picker,
  /// matching [search] on the server.
  Future<List<LinkedRecord>> listOpportunities({String? search}) =>
      _listLinked(AppConstants.crmLeadModel, const [
        ['type', '=', _opportunityType],
      ], search);

  /// Searches on the server rather than filtering one fetched page on the
  /// device: a company with more records than a page holds could otherwise
  /// never find the ones past it.
  Future<List<LinkedRecord>> _listLinked(
    String model,
    List<dynamic> domain,
    String? search,
  ) async {
    final query = search?.trim() ?? '';
    final rows = await api.searchRead(
      model,
      domain: [
        ...domain,
        if (query.isNotEmpty) ['name', 'ilike', query],
      ],
      fields: const ['id', 'name', 'partner_id'],
      limit: VisitConstants.pickerLimit,
      order: 'name asc',
    );
    return parseRows(
      rows,
      LinkedRecord.fromOdooRow,
      label: 'VisitsRepository.$model',
    );
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

  /// Throws [FormatException] for a row without an id, so `parseRows` skips it.
  factory LinkedRecord.fromOdooRow(Map<String, dynamic> row) {
    final partner = odooMany2one(row['partner_id']);
    return LinkedRecord(
      id:
          odooInt(row['id']) ??
          (throw const FormatException('linked record without an id')),
      name: odooString(row['name']) ?? '',
      partnerId: partner.id,
      partnerName: partner.name,
    );
  }
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
