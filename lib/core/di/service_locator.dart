import 'package:cookie_jar/cookie_jar.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/server_config_repository.dart';
import '../location/location_service.dart';
import '../network/connectivity_status.dart';
import '../network/pending_actions_queue.dart';
import '../settings/settings_repository.dart';
import '../storage/session_storage.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/customers/data/customers_repository.dart';
import '../../features/employees/data/employees_repository.dart';
import '../../features/live_location/data/live_location_repository.dart';
import '../../features/nearby/data/nearby_repository.dart';
import '../../features/visits/data/visits_repository.dart';

final GetIt sl = GetIt.instance;

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
  sl.registerSingleton<ApiClient>(ApiClient(
    cookieJar: cookieJar,
    connectivity: connectivity,
    baseUrl: serverConfig.baseUrl,
  ));
  sl.registerSingleton<SessionStorage>(SessionStorage());
  sl.registerSingleton<LocationService>(LocationService());
  sl.registerSingleton<SettingsRepository>(SettingsRepository(prefs: prefs));

  sl.registerSingleton<AuthRepository>(AuthRepository(
      api: sl(), session: sl(), cookieJar: sl(), serverConfig: sl()));
  sl.registerSingleton<CustomersRepository>(CustomersRepository(api: sl()));
  sl.registerSingleton<EmployeesRepository>(EmployeesRepository(api: sl()));
  sl.registerSingleton<VisitsRepository>(
      VisitsRepository(api: sl(), session: sl()));
  sl.registerSingleton<LiveLocationRepository>(
      LiveLocationRepository(api: sl(), session: sl()));
  sl.registerSingleton<NearbyRepository>(NearbyRepository(api: sl()));

  final queue = PendingActionsQueue(
    prefs: prefs,
    repository: sl<VisitsRepository>(),
    connectivity: connectivity,
  );
  queue.startBackgroundFlush();
  sl.registerSingleton<PendingActionsQueue>(queue);
}
