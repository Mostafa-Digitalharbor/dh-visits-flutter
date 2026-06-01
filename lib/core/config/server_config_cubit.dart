import 'package:bloc/bloc.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import 'server_config.dart';
import 'server_config_repository.dart';

/// Owns the active [ServerConfig] and keeps the [ApiClient] pointed at it.
///
/// The router listens to this cubit so that clearing/saving the server URL
/// re-runs the redirect (setup ⇄ login) without a manual navigation.
class ServerConfigCubit extends Cubit<ServerConfig> {
  final ServerConfigRepository repository;
  final ApiClient apiClient;

  ServerConfigCubit({
    required this.repository,
    required this.apiClient,
  }) : super(repository.read()) {
    // Make sure the ApiClient reflects whatever was persisted at boot.
    apiClient.updateBaseUrl(state.baseUrl);
  }

  /// Persists the company's server coordinates and repoints the API client.
  Future<void> save({required String baseUrl, String? database}) async {
    final config = ServerConfig(
      baseUrl: ServerConfig.normalizeUrl(baseUrl),
      database: database?.trim().isEmpty ?? true ? null : database!.trim(),
    );
    await repository.save(config);
    apiClient.updateBaseUrl(config.baseUrl);
    emit(config);
  }

  /// Best-effort auto-detection of the Odoo database for the current server.
  ///
  /// Tries two strategies, in order:
  /// 1. `/web/database/list` — works on on-prem / single-tenant servers with
  ///    `list_db` enabled; we only accept it when there's exactly one db.
  /// 2. `/web/session/get_session_info` — on Odoo Online the host maps to a
  ///    single database, so the session info echoes its name even before login.
  ///
  /// Returns `null` when neither works (caller then asks the user to type it).
  Future<String?> detectDatabase() async {
    try {
      final result = await apiClient.jsonRpc(Endpoints.databaseList);
      if (result is List) {
        final dbs = result
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (dbs.length == 1) return dbs.first;
      }
    } catch (_) {
      // list_db disabled or not reachable — fall through to session info.
    }
    try {
      final info = await apiClient.jsonRpc(Endpoints.sessionInfo);
      if (info is Map) {
        final db = info['db'];
        if (db is String && db.isNotEmpty) return db;
      }
    } catch (_) {
      // ignore — detection simply failed.
    }
    return null;
  }

  /// Wipes the stored server so the app falls back to the setup screen.
  Future<void> clear() async {
    await repository.clear();
    apiClient.updateBaseUrl('');
    emit(ServerConfig.empty);
  }
}
