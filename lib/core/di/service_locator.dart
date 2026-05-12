import 'package:cookie_jar/cookie_jar.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../location/location_service.dart';
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
  sl.registerSingleton<ApiClient>(ApiClient(cookieJar: cookieJar));
  sl.registerSingleton<SessionStorage>(SessionStorage());
  sl.registerSingleton<LocationService>(LocationService());
  sl.registerSingleton<SettingsRepository>(SettingsRepository(prefs: prefs));

  sl.registerSingleton<AuthRepository>(
      AuthRepository(api: sl(), session: sl(), cookieJar: sl()));
  sl.registerSingleton<CustomersRepository>(CustomersRepository(api: sl()));
  sl.registerSingleton<EmployeesRepository>(EmployeesRepository(api: sl()));
  sl.registerSingleton<VisitsRepository>(VisitsRepository(api: sl()));
  sl.registerSingleton<LiveLocationRepository>(
      LiveLocationRepository(api: sl()));
  sl.registerSingleton<NearbyRepository>(NearbyRepository(api: sl()));
}
