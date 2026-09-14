import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/app_environment.dart';
import '../config/server_config_repository.dart';
import '../constants.dart';
import '../map_matching/osrm_map_matcher.dart';
import '../map_matching/route_match_cache.dart';
import '../map_matching/route_matcher.dart';
import '../location/location_describe.dart';
import '../location/location_service.dart';
import '../network/connectivity_status.dart';
import '../network/pending_actions_queue.dart';
import '../network/server_clock.dart';
import '../push/push_notification_service.dart';
import '../push/push_repository.dart';
import '../settings/settings_repository.dart';
import '../storage/session_storage.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/customers/data/customers_repository.dart';
import '../../features/employees/data/employees_repository.dart';
import '../../features/live_location/data/live_location_repository.dart';
import '../../features/nearby/data/nearby_repository.dart';
import '../../features/visits/data/visit_trail_tracker.dart';
import '../../features/visits/data/visits_repository.dart';
import '../../features/workday/data/workday_repository.dart';
import '../../features/workday/data/workday_tracker.dart';

final GetIt sl = GetIt.instance;

/// Resolves [T] from the locator, or null when nothing is registered for it.
///
/// The app registers everything in [setupServiceLocator], but a widget test
/// registers only what the screen under test actually needs. A screen reaching
/// for an *optional* collaborator — the GPS-trail tracker, which a detail page
/// renders without but works better with — must degrade to "not available"
/// instead of throwing `GetIt: not registered` out of a `BlocProvider.create`,
/// which takes the whole screen down rather than the one feature.
T? slMaybe<T extends Object>() => sl.isRegistered<T>() ? sl<T>() : null;

Future<void> setupServiceLocator() async {
  final dir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
  final prefs = await SharedPreferences.getInstance();

  sl.registerSingleton<SharedPreferences>(prefs);
  sl.registerSingleton<PersistCookieJar>(cookieJar);

  // Resolve the per-company backend before building the API client so the
  // first request already targets the user's stored server.
  final serverConfigRepo = ServerConfigRepository(prefs: prefs);
  sl.registerSingleton<ServerConfigRepository>(serverConfigRepo);
  final serverConfig = serverConfigRepo.read();

  final connectivity = ConnectivityStatus();
  sl.registerSingleton<ConnectivityStatus>(connectivity);
  final serverClock = ServerClock(prefs: prefs);
  sl.registerSingleton<ServerClock>(serverClock);
  sl.registerSingleton<ApiClient>(ApiClient(
    cookieJar: cookieJar,
    connectivity: connectivity,
    serverClock: serverClock,
    baseUrl: serverConfig.baseUrl,
  ));
  sl.registerSingleton<SessionStorage>(SessionStorage());
  sl.registerSingleton<LocationService>(LocationService());
  sl.registerSingleton<LocationDescriber>(LocationDescriber());
  sl.registerSingleton<SettingsRepository>(SettingsRepository(prefs: prefs));

  sl.registerSingleton<AuthRepository>(AuthRepository(
      api: sl(), session: sl(), cookieJar: sl(), serverConfig: sl()));
  // Odoo reports a dead session as `SessionExpiredException` inside an HTTP
  // 200; the client renews it with the stored credentials and retries the
  // refused call once before falling back to a logout.
  sl<ApiClient>().reauthenticate = sl<AuthRepository>().reauthenticate;
  sl.registerSingleton<CustomersRepository>(CustomersRepository(api: sl()));
  sl.registerSingleton<EmployeesRepository>(EmployeesRepository(api: sl()));
  sl.registerSingleton<AttendanceRepository>(
      AttendanceRepository(api: sl(), session: sl()));
  sl.registerSingleton<VisitsRepository>(
      VisitsRepository(api: sl(), session: sl(), attendance: sl()));
  sl.registerSingleton<LiveLocationRepository>(
      LiveLocationRepository(api: sl(), session: sl()));
  sl.registerSingleton<NearbyRepository>(NearbyRepository(api: sl()));

  // Push notifications: token registration goes through the same authenticated
  // ApiClient; the service owns the FCM lifecycle. See app.dart for the
  // login/logout hooks and docs/BACKEND_PUSH_NOTIFICATIONS.md.
  sl.registerSingleton<PushRepository>(PushRepository(api: sl()));
  sl.registerSingleton<PushNotificationService>(
      PushNotificationService(repository: sl(), prefs: prefs));

  final queue = PendingActionsQueue(
    prefs: prefs,
    repository: sl<VisitsRepository>(),
    connectivity: connectivity,
  );
  queue.startBackgroundFlush();
  sl.registerSingleton<PendingActionsQueue>(queue);

  // Collects the GPS trail while a visit is running. Registered after the
  // queue because it consults it before every flush: points for a visit whose
  // Start is still queued offline have nothing to attach to server-side.
  // Resolved lazily through a closure rather than passed directly so the
  // dependency stays one-way — the queue knows nothing about the tracker.
  sl.registerSingleton<VisitTrailTracker>(VisitTrailTracker(
    prefs: prefs,
    repository: sl<VisitsRepository>(),
    locationService: sl<LocationService>(),
    connectivity: connectivity,
    pendingActions: () => sl<PendingActionsQueue>(),
    serverClock: serverClock,
    deviceId: () => sl<PushNotificationService>().deviceId(),
  ));

  // The whole-workday route. Built on top of the visit tracker and then handed
  // to it as its location feed: while a work day is open, the work-day capture
  // is the single GPS source for both the day route and the running visit's
  // trail.
  sl.registerSingleton<WorkdayRepository>(WorkdayRepository(api: sl()));
  final workday = WorkdayTracker(
    prefs: prefs,
    repository: sl<WorkdayRepository>(),
    sessionStorage: sl<SessionStorage>(),
    locationService: sl<LocationService>(),
    connectivity: connectivity,
    serverClock: serverClock,
    deviceId: () => sl<PushNotificationService>().deviceId(),
    visitTracker: () => sl<VisitTrailTracker>(),
  );
  sl.registerSingleton<WorkdayTracker>(workday);
  sl<VisitTrailTracker>().feed = workday;

  // Road-following display geometry for recorded routes (work day and visit
  // trails). Only ever draws; the recorded points are never altered.
  final matchingUrl = AppEnvironment.mapMatchingUrl;
  sl.registerSingleton<RouteMatcher>(RouteMatcher(
    matcher: matchingUrl.isEmpty
        ? null
        : OsrmMapMatcher(
            baseUrl: matchingUrl,
            profile: AppEnvironment.mapMatchingProfile,
            userAgent: AppConstants.mapUserAgent,
            maxPoints: AppEnvironment.mapMatchingMaxPoints > 0
                ? AppEnvironment.mapMatchingMaxPoints
                : null,
          ),
    cache: RouteMatchCache(directory: Directory('${dir.path}/route_match_v1')),
  ));
}
