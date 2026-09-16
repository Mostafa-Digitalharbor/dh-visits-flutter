import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// The per-company backend coordinates the app talks to.
///
/// Why: the app is shipped to multiple companies, each running its own Odoo
/// server. Instead of baking one URL into the binary, the user enters their
/// organisation's server on the setup screen and we persist it here.
class ServerConfig extends Equatable {
  /// Normalised base URL (scheme included, no trailing slash). Empty means the
  /// user hasn't configured a server yet.
  final String baseUrl;

  /// Optional Odoo database name. Empty/`null` means fall back to the
  /// build-time default (see [AppConstants.database]).
  final String? database;

  const ServerConfig({required this.baseUrl, this.database});

  static const empty = ServerConfig(baseUrl: '');

  static const secureScheme = 'https';
  static const insecureScheme = 'http';

  /// Whether a plain `http://` address may be saved.
  ///
  /// Release builds refuse it: the sign-in request carries the password, and
  /// `dart:io` sockets are not covered by the platform cleartext policies
  /// (`usesCleartextTraffic`, App Transport Security), so nothing else would
  /// stop it travelling unencrypted. Debug builds allow it for a local Odoo.
  static const allowsInsecureHttp = kDebugMode;

  /// True once both a server URL and a database are known — Odoo needs both to
  /// authenticate, so an incomplete setup (URL but no resolved database) keeps
  /// the user on the setup screen instead of a login that can't possibly work.
  bool get isConfigured =>
      baseUrl.isNotEmpty && (database?.isNotEmpty ?? false);

  /// The host part of [baseUrl], for messages and the profile's server row.
  String get host => hostOf(baseUrl);

  /// Normalises raw user input into a canonical *origin* URL:
  /// - trims whitespace
  /// - defaults a missing scheme to `https://`
  /// - keeps only `scheme://host[:port]`, dropping any path/query/fragment.
  ///
  /// Why drop the path: users often paste the full browser address bar
  /// (e.g. `https://co.odoo.com/web/login?redirect=/odoo`). If we kept that,
  /// every API call would be appended to `/web/login?...` and hit Odoo's HTML
  /// login form (CSRF error) instead of the JSON-RPC endpoints.
  static String normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('$insecureScheme://') &&
        !s.startsWith('$secureScheme://')) {
      s = '$secureScheme://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) {
      // Couldn't parse — fall back to just stripping trailing slashes so we
      // don't lose whatever the user typed.
      while (s.endsWith('/')) {
        s = s.substring(0, s.length - 1);
      }
      return s;
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Returns `true` if [input] (after normalisation) is a structurally valid
  /// absolute URL with a host — used by the setup form validator.
  static bool isValidUrl(String input) {
    final normalized = normalizeUrl(input);
    if (normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == insecureScheme || uri.scheme == secureScheme) &&
        uri.host.isNotEmpty &&
        uri.host.contains('.');
  }

  /// Whether [input] explicitly asks for an unencrypted `http://` connection.
  /// A bare host is not insecure: [normalizeUrl] gives it `https://`.
  static bool isInsecure(String input) =>
      Uri.tryParse(normalizeUrl(input))?.scheme == insecureScheme;

  /// The host of [url] (`co.odoo.com`), or [url] itself when it can't be
  /// parsed — messages still need something to name.
  static String hostOf(String url) {
    final host = Uri.tryParse(normalizeUrl(url))?.host ?? '';
    return host.isEmpty ? url.trim() : host;
  }

  @override
  List<Object?> get props => [baseUrl, database];
}
