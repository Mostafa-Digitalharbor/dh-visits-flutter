import '../../l10n/generated/app_localizations.dart';
import 'api_exceptions.dart';
import 'server_message_l10n.dart';

/// Turns an [ApiException] into the one sentence a user reads.
///
/// Takes [AppLocalizations] rather than a `BuildContext` so the mapping can be
/// exercised without a widget tree — the live API suite renders every failure
/// it provokes through here, in both languages. Widgets reach it through
/// `ApiExceptionL10n.localize(context)`.
extension ApiErrorMessages on ApiException {
  /// The server's own message, but only when the user can actually read it.
  ///
  /// [ApiException.serverMessage] already excludes Python diagnostics, so what
  /// reaches here is a sentence a human wrote — in English, because the backend
  /// has no other language installed. Three outcomes, in order:
  ///
  /// 1. It is a rule [ServerMessageL10n] knows → return the localized version,
  ///    which keeps the specifics ("only an approved visit can be started").
  /// 2. It is unrecognised but already in the UI's language → pass it through;
  ///    a new backend message is still better than a generic one.
  /// 3. It is unrecognised and in the *other* language → drop it, and let the
  ///    caller fall back to its localized default. An English sentence dropped
  ///    into an Arabic screen is the case this whole path exists to prevent.
  String? _serverText(AppLocalizations s) {
    final raw = serverMessage?.trim();
    if (raw == null || raw.isEmpty) return null;

    final translated = ServerMessageL10n.translate(s, raw);
    if (translated != null) return translated;

    return ServerMessageL10n.readableIn(s, raw) ? raw : null;
  }

  /// A short code to print under the message when support has to look into
  /// the failure (a bug, a server fault, an unreadable reply) — so the
  /// screenshot [ApiErrorCode.unknown]'s message asks for says which one it
  /// was. Null for failures the user fixes themselves.
  String? get supportReference => switch (code) {
        ApiErrorCode.unknown ||
        ApiErrorCode.server ||
        ApiErrorCode.invalidResponse ||
        ApiErrorCode.notSupported =>
          code.name,
        _ => null,
      };

  /// Every message states what went wrong *and* what the user can do about it:
  /// the person reading it cannot see logs, only the screen.
  String messageFor(AppLocalizations s) {
    switch (code) {
      case ApiErrorCode.invalidCredentials:
        return s.errInvalidCredentials;
      case ApiErrorCode.unauthorized:
        return s.errAuthRequired;
      case ApiErrorCode.permissionDenied:
        // An Odoo `AccessError` names what was refused ("you may not add
        // positions to this visit"); docs/API.md says to show it.
        return _serverText(s) ?? s.errPermissionDenied;
      case ApiErrorCode.timeout:
        return s.errNetworkTimeout;
      case ApiErrorCode.network:
        return s.errNetworkUnreachable;
      case ApiErrorCode.validation:
        return _serverText(s) ?? s.errValidation;
      case ApiErrorCode.notFound:
        return _serverText(s) ?? s.errNotFound;
      case ApiErrorCode.locationRequired:
        return s.errLocationRequired;
      case ApiErrorCode.server:
        return _serverText(s) ?? s.errServerError;
      case ApiErrorCode.serverUnavailable:
        return s.errServerUnavailable;
      case ApiErrorCode.rateLimited:
        return s.errRateLimited;
      case ApiErrorCode.payloadTooLarge:
        return s.errPayloadTooLarge;
      case ApiErrorCode.invalidResponse:
        return s.errInvalidResponse;
      case ApiErrorCode.databaseNotFound:
        return s.errDatabaseNotFound;
      case ApiErrorCode.locationPermission:
        return s.errLocationPermission;
      case ApiErrorCode.notSupported:
        return s.errFeatureNotAvailable;
      case ApiErrorCode.sessionRestoreFailed:
        return s.errSessionRestoreFailed;
      case ApiErrorCode.conflict:
        return _serverText(s) ?? s.errConflict;
      case ApiErrorCode.insecureConnection:
        return s.errInsecureConnection;
      case ApiErrorCode.unknown:
        // errUnknown, not errNetworkUnknown: this arm catches parse errors,
        // null casts and unclassified failures as well as network ones, and
        // "a network error occurred" sends the user off to check their WiFi
        // over what is usually a bug. `network` / `timeout` already carry the
        // genuinely connectivity-related cases.
        return _serverText(s) ?? s.errUnknown;
    }
  }
}
