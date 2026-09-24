// Fakes, fixtures and pump helpers shared by the feature-component suites
// under test/features/.
//
// Same approach as the screen suites (responsive_detail_screens_test.dart,
// visit_detail_cubit_test.dart): `implements X` plus a throwing
// `noSuchMethod`, so a widget that grows a new backend call fails loudly here
// instead of silently rendering an empty state. No mocking package.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/location/location_describe.dart';
import 'package:location_gps/core/location/location_outcome.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/map_matching/osrm_map_matcher.dart';
import 'package:location_gps/core/map_matching/route_geometry.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/core/network/server_clock.dart';
import 'package:location_gps/features/auth/bloc/auth_bloc.dart';
import 'package:location_gps/features/auth/data/auth_repository.dart';
import 'package:location_gps/features/auth/data/models/user.dart';
import 'package:location_gps/features/visits/bloc/visit_bloc.dart' as vb;
import 'package:location_gps/features/visits/bloc/visits_list_bloc.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_attachment.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/l10n/generated/app_localizations.dart';

import '../widgets/widget_harness.dart';

// ─── Users ───────────────────────────────────────────────────────────────────

/// A field rep: owns the visits built with [ownerEmployeeId].
const ownerEmployeeId = 10;

const fieldRep = AuthUser(
  uid: 1,
  username: 'rep@test.com',
  employeeName: LongText.arabicPerson,
  employeeId: ownerEmployeeId,
  visitRole: VisitRole.user,
);

/// A manager who is not the visit's owner.
const manager = AuthUser(
  uid: 2,
  username: 'mona@test.com',
  employeeName: 'منى عادل عبد الرحمن الشمري',
  employeeId: 20,
  visitRole: VisitRole.manager,
  isManager: true,
);

/// A manager who owns the visit (planned it for themself).
const managerOwner = AuthUser(
  uid: 3,
  username: 'lead@test.com',
  employeeName: 'Lead',
  employeeId: ownerEmployeeId,
  visitRole: VisitRole.manager,
  isManager: true,
);

/// A signed-in user with no rights over the visit.
const stranger = AuthUser(
  uid: 4,
  username: 'other@test.com',
  employeeId: 99,
  visitRole: VisitRole.user,
);

// ─── Fixtures ────────────────────────────────────────────────────────────────

final DateTime fixtureDay = DateTime.utc(2026, 9, 16, 7);

/// A visit with every optional field the detail widgets render populated.
Visit richVisit({
  int id = 42,
  VisitState state = VisitState.done,
  int? employeeId = ownerEmployeeId,
  String? partnerName = LongText.arabicCompany,
  int? partnerId,
}) {
  final at = fixtureDay;
  return Visit(
    id: id,
    name: 'VIS/2026/00042',
    visitType: VisitType.project,
    projectName: 'مشروع تطوير الواجهة البحرية — المرحلة الثانية',
    partnerId: partnerId,
    partnerName: partnerName,
    employeeId: employeeId,
    employeeName: LongText.arabicPerson,
    directManagerName: LongText.arabicPerson,
    higherManagerName: 'منى عادل عبد الرحمن الشمري',
    purpose: 'زيارة متابعة لمناقشة تفاصيل العقد والجدول الزمني للتسليم '
        'ومراجعة الملاحظات الفنية الواردة من فريق التنفيذ',
    location: 'طريق الملك عبد العزيز، حي الملقا، الرياض ١٢٤٧٣، السعودية',
    outcome: 'تم الاتفاق على تسليم الدفعة الأولى خلال أسبوعين',
    scheduledDatetime: at,
    startDatetime: at.add(const Duration(minutes: 5)),
    endDatetime: at.add(const Duration(hours: 1, minutes: 20)),
    startLat: 24.7136,
    startLng: 46.6753,
    endLat: 24.7140,
    endLng: 46.6760,
    startLocation: 'حي الملقا، الرياض',
    endLocation: 'حي الملقا، الرياض',
    state: state,
  );
}

/// [count] fixes walking north-east from Riyadh, a minute apart.
List<VisitLocationLog> trailLogs(
  int count, {
  DateTime? from,
  String? location = 'طريق الملك فهد، العليا، الرياض',
}) {
  final start = from ?? fixtureDay;
  return [
    for (var i = 0; i < count; i++)
      VisitLocationLog(
        id: i + 1,
        loggedAt: start.add(Duration(minutes: i)),
        latitude: 24.70 + i * 0.002,
        longitude: 46.67 + i * 0.002,
        accuracy: i.isEven ? 12 : 0,
        speed: i.isEven ? 8.5 : null,
        location: location,
        source: i == 0
            ? TrailSource.start
            : (i == count - 1 && count > 1 ? TrailSource.end : TrailSource.track),
      ),
  ];
}

VisitTrack trackOf(int visitId, int count, {double km = 3.42}) => VisitTrack(
      visitId: visitId,
      locationLogCount: count,
      trackedDistanceKm: count > 1 ? km : 0,
      logs: trailLogs(count),
    );

List<LatLng> latLngs(List<VisitLocationLog> logs) =>
    [for (final l in logs) LatLng(l.latitude, l.longitude)];

// ─── Repositories ────────────────────────────────────────────────────────────

class FakeVisitsRepo implements VisitsRepository {
  FakeVisitsRepo({
    this.visit,
    this.track = VisitTrack.empty,
    this.partner,
  });

  /// Served to `readVisitFull` / `getVisit`.
  Visit? visit;

  /// Served to `readTrack` unless [onReadTrack] is set.
  VisitTrack track;
  Future<VisitTrack> Function(int visitId)? onReadTrack;
  int readTrackCalls = 0;

  PartnerLocation? partner;
  int partnerLocationCalls = 0;

  /// Every workflow call that reached the "wire", in order.
  final List<String> calls = [];

  /// Held open by a test that needs an action to stay in flight.
  Completer<void>? actionGate;

  Future<void> _gate() async {
    final gate = actionGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<Visit?> readVisitFull(int visitId) async => visit;

  @override
  Future<Visit?> getVisit(int visitId) async => visit;

  @override
  Future<List<VisitAttachment>> readAttachments(int visitId) async => const [];

  @override
  Future<bool> hasMockLocationFlag(int visitId) async => false;

  @override
  Future<VisitTrack> readTrack(
    int visitId, {
    int? limit,
    int offset = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    readTrackCalls++;
    final handler = onReadTrack;
    if (handler != null) return handler(visitId);
    return Future.value(track);
  }

  @override
  Future<PartnerLocation?> partnerLocation(int partnerId) async {
    partnerLocationCalls++;
    return partner;
  }

  @override
  Future<String?> submit(int visitId) async {
    calls.add('submit');
    await _gate();
    return null;
  }

  @override
  Future<String?> approve(int visitId) async {
    calls.add('approve');
    await _gate();
    return null;
  }

  @override
  Future<String?> reject(int visitId, String reason) async {
    calls.add('reject:$reason');
    return null;
  }

  @override
  Future<void> cancel(int visitId) async => calls.add('cancel');

  @override
  Future<String?> reschedule(
    int visitId, {
    DateTime? scheduledDatetime,
    String? purpose,
    String? location,
  }) async {
    calls.add('reschedule:${scheduledDatetime?.toIso8601String()}|'
        '$purpose|$location');
    return null;
  }

  @override
  Future<VisitTransition> start(
    int visitId, {
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    calls.add('start:$latitude,$longitude|$location|mocked=$isMocked');
    return (state: VisitState.inProgress, at: fixtureDay);
  }

  @override
  Future<VisitTransition> end(
    int visitId, {
    required String outcome,
    double? latitude,
    double? longitude,
    String? location,
    bool isMocked = false,
  }) async {
    calls.add('end:$outcome|$latitude,$longitude|$location|mocked=$isMocked');
    return (state: VisitState.done, at: fixtureDay);
  }

  @override
  Future<int?> uploadAttachment(
    int visitId, {
    required String filename,
    required String dataB64,
  }) async {
    calls.add('upload:$filename');
    return 1;
  }

  @override
  Future<void> approveParticipant(int participantId) async =>
      calls.add('approveParticipant:$participantId');

  @override
  Future<void> rejectParticipant(int participantId, String reason) async =>
      calls.add('rejectParticipant:$participantId|$reason');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

class FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

// ─── Blocs ───────────────────────────────────────────────────────────────────

/// An auth bloc parked on [user] (or signed out) without touching a network.
class StubAuthBloc extends AuthBloc {
  StubAuthBloc(AuthUser? user) : super(repository: FakeAuthRepo()) {
    if (user != null) emit(AuthState.authenticated(user));
  }

  @override
  void add(AuthEvent event) {}
}

/// A visits list bloc whose state the test drives with [push].
class StubListBloc extends VisitsListBloc {
  StubListBloc([VisitsListState? initial])
      : super(repository: FakeVisitsRepo()) {
    if (initial != null) emit(initial);
  }

  void push(VisitsListState next) => emit(next);

  @override
  void add(VisitsListEvent event) {}
}

/// The active-visit bloc, driven by [push].
class StubVisitBloc extends vb.VisitBloc {
  StubVisitBloc([vb.VisitState? initial])
      : super(repository: FakeVisitsRepo()) {
    if (initial != null) emit(initial);
  }

  void push(vb.VisitState next) => emit(next);

  @override
  void add(vb.VisitEvent event) {}
}

// ─── Device services ─────────────────────────────────────────────────────────

class FakeTrailTracker implements VisitTrailTracker {
  final ValueNotifier<TrailCaptureStatus> statusNotifier =
      ValueNotifier(const TrailCaptureStatus());
  final ValueNotifier<int> pendingNotifier = ValueNotifier(0);
  final ValueNotifier<int> revisionNotifier = ValueNotifier(0);

  /// What [pendingCount] drops to once [flushNow] has run.
  int pendingAfterFlush = 0;

  int retryCalls = 0;
  int drainCalls = 0;
  int flushCalls = 0;

  @override
  ValueListenable<TrailCaptureStatus> get status => statusNotifier;

  @override
  ValueListenable<int> get pendingCount => pendingNotifier;

  @override
  ValueListenable<int> get revision => revisionNotifier;

  @override
  Future<void> retry() async => retryCalls++;

  @override
  Future<void> drain() async => drainCalls++;

  @override
  Future<void> flushNow({bool probe = false}) async {
    flushCalls++;
    pendingNotifier.value = pendingAfterFlush;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.outcome = const LocationOk(latitude: 24.7136, longitude: 46.6753),
    this.access = LocationAccess.granted,
  });

  LocationOutcome outcome;
  LocationAccess access;
  int acquireCalls = 0;
  int requestAccessCalls = 0;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<LocationOutcome> acquire({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    acquireCalls++;
    return outcome;
  }

  @override
  Future<LocationAccess> requestAccess() async {
    requestAccessCalls++;
    return access;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

class FakeDescriber implements LocationDescriber {
  static const label = 'شارع العليا، الرياض';
  final List<String?> locales = [];

  @override
  Future<String> describe(
    double latitude,
    double longitude, {
    String? localeIdentifier,
  }) async {
    locales.add(localeIdentifier);
    return label;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

class FakePendingQueue implements PendingActionsQueue {
  FakePendingQueue([this.items = const []]);
  final List<PendingAction> items;

  @override
  List<PendingAction> get pending => items;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

/// A server clock the test moves by hand.
class FixedServerClock implements ServerClock {
  FixedServerClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unstubbed: ${invocation.memberName}');
}

/// A road matcher that answers "no road here" for every edge, at once.
class NoRoadMatcher implements MapMatcher {
  int matchCalls = 0;

  @override
  String get cacheId => 'no-road';

  @override
  int get maxPoints => 100;

  @override
  Future<List<List<LatLng>?>> match(List<TracePoint> points) async {
    matchCalls++;
    return List<List<LatLng>?>.filled(points.length - 1, null);
  }
}

// ─── Platform channels ───────────────────────────────────────────────────────

const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

/// Answers url_launcher's channel and records every URL it was asked to open.
/// [canLaunch] false sends `openInMaps` down its web fallback.
/// [error] makes every call fail with it instead.
List<String> mockUrlLauncher({
  bool canLaunch = true,
  bool launches = true,
  Object? error,
}) {
  final launched = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(urlLauncherChannel, (call) async {
    if (error != null) throw error;
    final url = (call.arguments as Map)['url'] as String;
    switch (call.method) {
      case 'canLaunch':
        return canLaunch;
      case 'launch':
        launched.add(url);
        return launches;
    }
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(urlLauncherChannel, null));
  return launched;
}

// ─── Pumping ─────────────────────────────────────────────────────────────────

/// Wraps [child] in the given blocs (any may be null).
Widget withBlocs(
  Widget child, {
  AuthBloc? auth,
  VisitsListBloc? list,
  vb.VisitBloc? visit,
  List<BlocProvider> extra = const [],
}) {
  final providers = <BlocProvider>[
    if (auth != null) BlocProvider<AuthBloc>.value(value: auth),
    if (list != null) BlocProvider<VisitsListBloc>.value(value: list),
    if (visit != null) BlocProvider<vb.VisitBloc>.value(value: visit),
    ...extra,
  ];
  if (providers.isEmpty) return child;
  return MultiBlocProvider(providers: providers, child: child);
}

/// Where a routed test navigated to.
class RouteLog {
  final List<String> locations = [];
  final List<Object?> extras = [];
}

/// Like [pumpSurface], but inside a [GoRouter] so `context.push` works. Every
/// pushed location lands on a stub page and is recorded in the returned log.
Future<RouteLog> pumpRouted(
  WidgetTester tester,
  Surface surface,
  Widget child, {
  Widget Function(Widget app)? wrap,
}) async {
  tester.view.physicalSize = surface.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final log = RouteLog();
  Widget stub(BuildContext context, GoRouterState state) {
    log.locations.add(state.uri.toString());
    log.extras.add(state.extra);
    return Scaffold(body: Text('route ${state.uri}'));
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: SafeArea(child: child)),
      ),
      GoRoute(path: '/visits/:id', builder: stub),
      GoRoute(path: '/visits/:id/trail', builder: stub),
      GoRoute(path: '/customers/:id', builder: stub),
    ],
  );
  addTearDown(router.dispose);

  final Widget app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: surface.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light,
    locale: surface.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(surface.textScale),
      ),
      child: app!,
    ),
    routerConfig: router,
  );
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await tester.pump(const Duration(milliseconds: 600));
  return log;
}

/// The context of the first widget matched by [finder].
BuildContext contextOf(WidgetTester tester, Finder finder) =>
    tester.element(finder.first);

/// Pumps fixed frames: several widgets here host an [AmbientPulse] or a
/// ticking timer, which never let `pumpAndSettle` return.
Future<void> pumpFrames(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 800),
]) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Which way an arrow-like [icon] actually points once [Icon] has applied its
/// `matchTextDirection` mirroring. `true` means towards the end of the line
/// in [direction] (right in English, left in Arabic).
bool chevronPointsToEnd(IconData icon, TextDirection direction) {
  final drawnRight = switch (icon.codePoint) {
    _ when icon == Icons.chevron_right => true,
    _ when icon == Icons.chevron_left => false,
    _ => throw ArgumentError('not a chevron: $icon'),
  };
  final mirrored = icon.matchTextDirection && direction == TextDirection.rtl;
  final pointsRight = drawnRight != mirrored;
  return direction == TextDirection.ltr ? pointsRight : !pointsRight;
}

// ─── Maps ────────────────────────────────────────────────────────────────────
//
// The harness's `expectCleanLayout` tolerates *one* tile failure, but a real
// map requests a dozen tiles and the binding folds them into a single
// "Multiple exceptions (16) were detected" that no longer names the tile host.
// Map suites therefore drop tile failures before the binding sees them, the
// same way responsive_detail_screens_test.dart does, and restore the handler
// before the body returns (in `finally`, so a failing expect still reports its
// own message rather than the binding's "overrode FlutterError.onError").

bool _isTileFailure(FlutterErrorDetails details) =>
    '${details.exception}'.contains('tile.openstreetmap.org');

Future<void> ignoringTileFailures(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!_isTileFailure(details)) previous?.call(details);
  };
  try {
    await body();
    // Unmount while still filtering: tile loads still in flight fail on the
    // way out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  } finally {
    FlutterError.onError = previous;
  }
}

/// [testWidgets] for a widget that hosts a map.
void testMapWidgets(String description, WidgetTesterCallback body) {
  testWidgets(
    description,
    (tester) => ignoringTileFailures(tester, () => body(tester)),
  );
}

/// [testOnEverySurface] for a widget that hosts a map.
void testMapOnEverySurface(
  String description,
  Widget Function(Surface surface) build, {
  bool scrollable = false,
  Future<void> Function(WidgetTester tester, Surface surface)? verify,
}) {
  for (final surface in surfaces) {
    testMapWidgets('$description — $surface', (tester) async {
      await pumpSurface(tester, surface, build(surface),
          scrollable: scrollable);
      expectCleanLayout(tester);
      if (verify != null) await verify(tester, surface);
      expectCleanLayout(tester);
    });
  }
}
