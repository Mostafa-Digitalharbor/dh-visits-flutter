import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/location/location_outcome.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/workday_location_channel.dart';
import '../../../core/utils/app_log.dart';
import '../data/workday_tracker.dart';

enum WorkdayProblem {
  permissionDenied,

  /// Android no longer shows the prompt; only Settings can grant it.
  permissionDeniedForever,
  serviceDisabled,

  /// Only approximate location is granted: a route can't be recorded.
  preciseLocationOff,
  locationUnavailable,
  unsupported,
  failed,
}

enum WorkdayOutcome { started, ended, endQueued }

class WorkdayState extends Equatable {
  final WorkdayStatus status;
  final bool busy;
  final WorkdayProblem? problem;
  final ApiException? error;
  final WorkdayOutcome? outcome;

  /// Bumped with every problem or outcome, so the same one twice still
  /// reaches a listener.
  final int eventSeq;

  const WorkdayState({
    required this.status,
    this.busy = false,
    this.problem,
    this.error,
    this.outcome,
    this.eventSeq = 0,
  });

  @override
  List<Object?> get props => [status, busy, problem, error, outcome, eventSeq];
}

/// The Start / End work day actions and their permission handling. The work
/// day itself lives in [WorkdayTracker]; this only mirrors its status.
///
/// Order of a first Start (Google Play's prominent-disclosure and Apple's
/// "explain before asking" rules): the in-app disclosure is accepted
/// ([acceptDisclosure], shown by the view), then the location permission
/// prompt, then — iOS only, once — the "Always" upgrade prompt, which the
/// disclosure already explained. None of it blocks a work day that can run:
/// "While Using" is enough for background capture started from the app.
class WorkdayCubit extends Cubit<WorkdayState> {
  final WorkdayTracker tracker;
  final LocationService locationService;

  /// Where the disclosure acceptance is remembered. Null (widget tests):
  /// treated as accepted.
  final SharedPreferences? prefs;

  /// Android 13+ needs the notification permission for the ongoing tracking
  /// notification to be *visible*; capture works either way. Injectable for
  /// tests.
  final Future<void> Function() requestNotificationPermission;

  WorkdayCubit({
    required this.tracker,
    required this.locationService,
    this.prefs,
    Future<void> Function()? requestNotificationPermission,
  })  : requestNotificationPermission =
            requestNotificationPermission ?? _askNotifications,
        super(WorkdayState(status: tracker.status.value)) {
    tracker.status.addListener(_onStatus);
  }

  /// Bump the version when the disclosure text changes materially, so every
  /// user reads the new one before their next Start.
  static const String disclosureKey = 'workday_disclosure_v1';
  static const String alwaysAskedKey = 'workday_always_requested_v1';

  static Future<void> _askNotifications() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Permission.notification.request();
    } catch (e) {
      appLog('[WorkdayCubit] notification permission request failed: $e');
    }
  }

  bool get disclosureAccepted {
    final store = prefs;
    return store == null || (store.getBool(disclosureKey) ?? false);
  }

  Future<void> acceptDisclosure() async {
    await prefs?.setBool(disclosureKey, true);
  }

  void _onStatus() {
    if (isClosed) return;
    emit(WorkdayState(
      status: tracker.status.value,
      busy: state.busy,
      eventSeq: state.eventSeq,
    ));
  }

  void _emit(WorkdayState next) {
    if (!isClosed) emit(next);
  }

  void _busy() => _emit(WorkdayState(
      status: tracker.status.value, busy: true, eventSeq: state.eventSeq));

  void _problem(WorkdayProblem problem, [ApiException? error]) =>
      _emit(WorkdayState(
        status: tracker.status.value,
        problem: problem,
        error: error,
        eventSeq: state.eventSeq + 1,
      ));

  void _done(WorkdayOutcome outcome) => _emit(WorkdayState(
        status: tracker.status.value,
        outcome: outcome,
        eventSeq: state.eventSeq + 1,
      ));

  /// Checks location access, returning the problem to report (or null).
  Future<WorkdayProblem?> _access() async {
    final problem = switch (await locationService.requestAccess()) {
      LocationAccess.granted => null,
      LocationAccess.denied => WorkdayProblem.permissionDenied,
      LocationAccess.deniedForever => WorkdayProblem.permissionDeniedForever,
      LocationAccess.serviceDisabled => WorkdayProblem.serviceDisabled,
    };
    if (problem != null) return problem;
    if (await locationService.isPreciseLocation()) return null;
    await locationService.requestPreciseLocation();
    return await locationService.isPreciseLocation()
        ? null
        : WorkdayProblem.preciseLocationOff;
  }

  /// iOS: after "While Using" was granted, asks once for "Always", which lets
  /// capture resume when iOS relaunches a terminated app. Never blocks.
  Future<void> _offerAlways() async {
    final store = prefs;
    if (store == null || store.getBool(alwaysAskedKey) == true) return;
    try {
      final auth = await tracker.channel.authorization();
      if (auth?.status != LocationAuthorizationStatus.whenInUse) return;
      await store.setBool(alwaysAskedKey, true);
      await tracker.channel.requestAlways();
    } catch (e) {
      appLog('[WorkdayCubit] Always authorization request failed: $e');
    }
  }

  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (state.busy) return;
    _busy();
    try {
      final denied = await _access();
      if (denied != null) return _problem(denied);
      await requestNotificationPermission();
      await _offerAlways();
      final fix = await locationService.acquire();
      switch (fix) {
        case LocationOk(:final latitude, :final longitude):
          await tracker.startDay(
            latitude: latitude,
            longitude: longitude,
            notificationTitle: notificationTitle,
            notificationText: notificationText,
          );
          _done(WorkdayOutcome.started);
        case LocationPermissionDenied():
          _problem(WorkdayProblem.permissionDenied);
        case LocationUnavailable():
          _problem(WorkdayProblem.locationUnavailable);
        case LocationCancelled():
          _emit(WorkdayState(
              status: tracker.status.value, eventSeq: state.eventSeq));
      }
    } on ApiException catch (e) {
      _problem(
        e.code == ApiErrorCode.notSupported
            ? WorkdayProblem.unsupported
            : WorkdayProblem.failed,
        e,
      );
    } catch (e) {
      _problem(WorkdayProblem.failed, ApiException.unexpected(e));
    }
  }

  /// Ends the work day. A fresh position is recorded as its end when one can
  /// be had; the day still ends without one (capture must stop regardless).
  Future<void> end() async {
    if (state.busy) return;
    _busy();
    try {
      double? latitude;
      double? longitude;
      final fix = await locationService.acquire();
      if (fix is LocationOk) {
        latitude = fix.latitude;
        longitude = fix.longitude;
      }
      final synced =
          await tracker.endDay(latitude: latitude, longitude: longitude);
      _done(synced ? WorkdayOutcome.ended : WorkdayOutcome.endQueued);
    } on ApiException catch (e) {
      _problem(WorkdayProblem.failed, e);
    } catch (e) {
      _problem(WorkdayProblem.failed, ApiException.unexpected(e));
    }
  }

  /// Restarts capture for an open day that lost it (permission revoked).
  Future<void> resumeCapture({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (state.busy) return;
    _busy();
    final denied = await _access();
    if (denied != null) return _problem(denied);
    await tracker.restore(
      notificationTitle: notificationTitle,
      notificationText: notificationText,
    );
    _emit(WorkdayState(status: tracker.status.value, eventSeq: state.eventSeq));
  }

  @override
  Future<void> close() {
    tracker.status.removeListener(_onStatus);
    return super.close();
  }
}
