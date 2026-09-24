// Start Work Day permission flow: disclosure before any prompt, precise
// location required, "Always" asked at most once on iOS and never blocking,
// and no broken work day when access is missing.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_gps/core/location/location_outcome.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/location/workday_location_channel.dart';
import 'package:location_gps/features/workday/bloc/workday_cubit.dart';
import 'package:location_gps/features/workday/data/workday_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Channel extends WorkdayLocationChannel {
  /// Null: a platform without Core Location authorization (Android).
  LocationAuthorizationStatus? authStatus = LocationAuthorizationStatus.whenInUse;
  int alwaysRequests = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<LocationAuthorization?> authorization() async => authStatus == null
      ? null
      : LocationAuthorization(status: authStatus!, precise: true, backgroundMode: true);

  @override
  Future<LocationAuthorization?> requestAlways() async {
    alwaysRequests++;
    authStatus = LocationAuthorizationStatus.always;
    return authorization();
  }
}

class _Tracker implements WorkdayTracker {
  _Tracker(this._channel);
  final _Channel _channel;
  final ValueNotifier<WorkdayStatus> _status =
      ValueNotifier(const WorkdayStatus(phase: WorkdayPhase.inactive));
  int starts = 0;

  @override
  ValueListenable<WorkdayStatus> get status => _status;

  @override
  WorkdayLocationChannel get channel => _channel;

  @override
  Future<void> startDay({
    required double latitude,
    required double longitude,
    required String notificationTitle,
    required String notificationText,
  }) async {
    starts++;
    _status.value = const WorkdayStatus(phase: WorkdayPhase.active, capturing: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends LocationService {
  LocationAccess access = LocationAccess.granted;

  /// Successive answers of isPreciseLocation; the last one repeats.
  List<bool> precise = [true];
  int preciseRequests = 0;

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Future<bool> isPreciseLocation() async =>
      precise.length > 1 ? precise.removeAt(0) : precise.first;

  @override
  Future<void> requestPreciseLocation() async => preciseRequests++;

  @override
  Future<LocationOutcome> acquire({LocationAccuracy accuracy = LocationAccuracy.high}) async =>
      const LocationOk(latitude: 24.7168, longitude: 46.6830);
}

void main() {
  late SharedPreferences prefs;
  late _Channel channel;
  late _Tracker tracker;
  late _Location location;

  WorkdayCubit cubit() => WorkdayCubit(
        tracker: tracker,
        locationService: location,
        prefs: prefs,
        requestNotificationPermission: () async {},
      );

  Future<WorkdayState> start(WorkdayCubit c) async {
    await c.start(notificationTitle: 't', notificationText: 'x');
    return c.state;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    channel = _Channel();
    tracker = _Tracker(channel);
    location = _Location();
  });

  test('the disclosure must be accepted once, and is remembered', () async {
    final first = cubit();
    expect(first.disclosureAccepted, isFalse);
    await first.acceptDisclosure();
    expect(cubit().disclosureAccepted, isTrue);
    expect(prefs.getBool(WorkdayCubit.disclosureKey), isTrue);
  });

  test('approximate location: asks for precise once, then refuses to start', () async {
    location.precise = [false, false];
    final state = await start(cubit());
    expect(state.problem, WorkdayProblem.preciseLocationOff);
    expect(location.preciseRequests, 1);
    expect(tracker.starts, 0, reason: 'no work day that cannot record a route');
  });

  test('precise location granted on request: the day starts', () async {
    location.precise = [false, true];
    final state = await start(cubit());
    expect(state.outcome, WorkdayOutcome.started);
    expect(tracker.starts, 1);
  });

  test('iOS While Using: "Always" is requested once, and the day starts either way', () async {
    final c = cubit();
    expect((await start(c)).outcome, WorkdayOutcome.started);
    expect(channel.alwaysRequests, 1);

    channel.authStatus = LocationAuthorizationStatus.whenInUse; // the user kept While Using
    await start(cubit());
    expect(channel.alwaysRequests, 1, reason: 'never asked twice');
    expect(tracker.starts, 2);
  });

  test('already Always, or Android (no Core Location): nothing extra is asked', () async {
    channel.authStatus = LocationAuthorizationStatus.always;
    await start(cubit());
    channel.authStatus = null;
    await start(cubit());
    expect(channel.alwaysRequests, 0);
    expect(tracker.starts, 2);
  });

  test('denied, blocked or services off: a problem, no work day', () async {
    for (final (access, problem) in [
      (LocationAccess.denied, WorkdayProblem.permissionDenied),
      (LocationAccess.deniedForever, WorkdayProblem.permissionDeniedForever),
      (LocationAccess.serviceDisabled, WorkdayProblem.serviceDisabled),
    ]) {
      location.access = access;
      expect((await start(cubit())).problem, problem);
    }
    expect(tracker.starts, 0);
    expect(channel.alwaysRequests, 0);
  });
}
