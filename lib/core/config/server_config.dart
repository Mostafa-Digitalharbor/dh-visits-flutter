import 'package:equatable/equatable.dart';

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

  /// True once both a server URL and a database are known — Odoo needs both to
  /// authenticate, so an incomplete setup (URL but no resolved database) keeps
  /// the user on the setup screen instead of a login that can't possibly work.
  bool get isConfigured =>
      baseUrl.isNotEmpty && (database?.isNotEmpty ?? false);

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
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
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
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.host.contains('.');
  }

  @override
  List<Object?> get props => [baseUrl, database];
}
