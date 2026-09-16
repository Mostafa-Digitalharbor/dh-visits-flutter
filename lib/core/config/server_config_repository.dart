import 'package:shared_preferences/shared_preferences.dart';

import 'app_environment.dart';
import 'server_config.dart';
import '../constants/storage_keys.dart';

/// Persists the user-selected backend coordinates in [SharedPreferences].
///
/// Seeds the stored value once from the build-time `--dart-define` defaults so
/// dev/CI builds that pass `API_BASE_URL` keep working without touching the
/// setup screen, while release builds start blank and force the setup flow.
class ServerConfigRepository {
  static const _kBaseUrl = StorageKeys.serverBaseUrl;
  static const _kDatabase = StorageKeys.serverDatabase;

  final SharedPreferences prefs;
  ServerConfigRepository({required this.prefs});

  ServerConfig read() {
    final storedUrl = prefs.getString(_kBaseUrl);
    final storedDb = prefs.getString(_kDatabase);
    // Fall back to the build-time seed only when nothing has been stored yet.
    final baseUrl = (storedUrl == null || storedUrl.isEmpty)
        ? AppEnvironment.baseUrl
        : storedUrl;
    final database = (storedDb == null || storedDb.isEmpty)
        ? (AppEnvironment.database.isEmpty ? null : AppEnvironment.database)
        : storedDb;
    return ServerConfig(
      baseUrl: ServerConfig.normalizeUrl(baseUrl),
      database: database,
    );
  }

  Future<void> save(ServerConfig config) async {
    await prefs.setString(_kBaseUrl, config.baseUrl);
    final db = config.database?.trim();
    if (db != null && db.isNotEmpty) {
      await prefs.setString(_kDatabase, db);
    } else {
      await prefs.remove(_kDatabase);
    }
  }

  Future<void> clear() async {
    await prefs.remove(_kBaseUrl);
    await prefs.remove(_kDatabase);
  }
}
