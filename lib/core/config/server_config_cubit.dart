import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../api/endpoints.dart';
import '../api/odoo_parse.dart';
import '../utils/app_log.dart';
import 'server_config.dart';
import 'server_config_repository.dart';

/// What probing a server address found. See [ServerConfigCubit.probe].
sealed class ServerProbe {
  const ServerProbe();
}

/// The address answers as Odoo.
final class ServerProbeOdoo extends ServerProbe {
  /// The databases the server lists, or null when it refuses to list them
  /// (`list_db = False`, or a proxy blocking the route) — the user then has to
  /// type the name.
  final List<String>? databases;

  const ServerProbeOdoo(this.databases);

  /// The database to use without asking, when the server has exactly one.
  String? get onlyDatabase =>
      databases?.length == 1 ? databases!.single : null;
}

/// Nothing usable answered; [error] says why (unreachable, not Odoo, an
/// untrusted certificate, a server outage…).
final class ServerProbeFailed extends ServerProbe {
  final ApiException error;
  const ServerProbeFailed(this.error);
}

/// Builds the client a probe talks through. Injectable for tests.
typedef ProbeClientFactory = ApiClient Function(String baseUrl);

/// Owns the active [ServerConfig] and keeps the [ApiClient] pointed at it.
///
/// The router listens to this cubit so that clearing/saving the server URL
/// re-runs the redirect (setup ⇄ login) without a manual navigation.
class ServerConfigCubit extends Cubit<ServerConfig> {
  final ServerConfigRepository repository;
  final ApiClient apiClient;
  final ProbeClientFactory _probeClient;

  ServerConfigCubit({
    required this.repository,
    required this.apiClient,
    ProbeClientFactory? probeClient,
  })  : _probeClient = probeClient ?? _ephemeralClient,
        super(repository.read()) {
    // Make sure the ApiClient reflects whatever was persisted at boot.
    apiClient.updateBaseUrl(state.baseUrl);
  }

  static const _serverVersionField = 'server_version';

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

  /// Asks [baseUrl] whether it is an Odoo server and which databases it hosts,
  /// **without** saving anything or touching the live [apiClient].
  ///
  /// This used to point the app's own client at the typed address first, so a
  /// signed-in user who merely tapped "Detect database" from Profile had their
  /// session silently repointed at another host — and a failed probe could
  /// fire the app-wide "unauthorized" stream and sign them out. A throwaway
  /// client with in-memory cookies keeps the probe side-effect free.
  ///
  /// Never throws: every failure comes back as [ServerProbeFailed].
  Future<ServerProbe> probe(String baseUrl) async {
    final url = ServerConfig.normalizeUrl(baseUrl);
    final client = _probeClient(url);
    try {
      final version = odooMap(await client.jsonRpc(Endpoints.versionInfo));
      if (version?[_serverVersionField] == null) {
        return ServerProbeFailed(ApiException(
          code: ApiErrorCode.invalidResponse,
          details: 'No $_serverVersionField from $url',
        ));
      }
      return ServerProbeOdoo(await _listDatabases(client));
    } on ApiException catch (e) {
      appLog('[ServerConfigCubit] probe of $url failed: $e');
      return ServerProbeFailed(_asProbeFailure(e));
    } catch (e) {
      appLog('[ServerConfigCubit] probe of $url threw: $e');
      return ServerProbeFailed(ApiException.unexpected(e));
    } finally {
      _release(client);
    }
  }

  /// The server's database list, or null when it won't say.
  ///
  /// By the time this runs the host has answered as Odoo, so a refusal here
  /// (`AccessDenied` with `list_db = False`, a 403/404 from a hardened proxy)
  /// means "type the name", not "wrong server". Only a connection that dropped
  /// in between is reported as a failure.
  Future<List<String>?> _listDatabases(ApiClient client) async {
    try {
      final result = await client.jsonRpc(Endpoints.databaseList);
      if (result is! List) return null;
      return result.map(odooString).whereType<String>().toList();
    } on ApiException catch (e) {
      if (_connectionFailures.contains(e.code)) rethrow;
      return null;
    }
  }

  static const _connectionFailures = {
    ApiErrorCode.network,
    ApiErrorCode.timeout,
    ApiErrorCode.serverUnavailable,
    ApiErrorCode.rateLimited,
    ApiErrorCode.insecureConnection,
  };

  /// Re-reads a failure in the probe's terms. On the version route, a missing
  /// route, a login wall or an unreadable body all mean the same thing: this
  /// address is not an Odoo server.
  static ApiException _asProbeFailure(ApiException e) {
    final code = switch (e.code) {
      ApiErrorCode.notFound ||
      ApiErrorCode.notSupported ||
      ApiErrorCode.unauthorized ||
      ApiErrorCode.permissionDenied =>
        ApiErrorCode.invalidResponse,
      ApiErrorCode.unknown when isCertificateFailure(e) =>
        ApiErrorCode.insecureConnection,
      _ => e.code,
    };
    return code == e.code
        ? e
        : ApiException(code: code, details: e.details, odooName: e.odooName);
  }

  /// Whether [e] is a rejected TLS certificate, including the case the client
  /// still files under `unknown`: Dio wraps a bare `HandshakeException` (not a
  /// `SocketException`) as an unclassified error, so the self-signed
  /// certificate of an on-premise Odoo read "something went wrong on our
  /// side". Drop the `unknown` arm once ApiClient classifies it itself.
  static bool isCertificateFailure(ApiException e) {
    if (e.code == ApiErrorCode.insecureConnection) return true;
    if (e.code != ApiErrorCode.unknown) return false;
    final text = '${e.details ?? ''}'.toLowerCase();
    return text.contains('handshake') || text.contains('certificate');
  }

  static ApiClient _ephemeralClient(String baseUrl) => ApiClient(
        cookieJar: PersistCookieJar(storage: _MemoryCookieStorage()),
        baseUrl: baseUrl,
      );

  static void _release(ApiClient client) {
    try {
      client.dio.close(force: true);
      unawaited(client.dispose());
    } catch (e) {
      // A test double without a transport; nothing to release.
      appLog('[ServerConfigCubit] probe client not released: $e');
    }
  }

  /// Wipes the stored server so the app falls back to the setup screen.
  Future<void> clear() async {
    await repository.clear();
    apiClient.updateBaseUrl('');
    emit(ServerConfig.empty);
  }
}

/// Cookie storage that lives only as long as one probe: the probed host's
/// session cookie must not end up in the app's persistent jar.
class _MemoryCookieStorage implements Storage {
  final _values = <String, String>{};

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll(List<String> keys) async =>
      keys.forEach(_values.remove);
}
