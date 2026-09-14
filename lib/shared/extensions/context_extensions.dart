import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/api/server_message_l10n.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/design/app_dimens.dart';
import '../../app/design/responsive.dart';

/// Visual kind for snackbars — drives the leading icon and accent color
/// on `context.showSnack`. Defaults to `info` for plain messages and
/// switches to `success` / `error` for explicit results.
enum SnackKind { info, success, error }

extension AppContext on BuildContext {
  AppLocalizations get s => AppLocalizations.of(this);
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Runs an external-launch action (dial / mail / maps) and, if it fails
  /// (no handler app, or the launch threw), shows a clear localized message
  /// instead of the tap silently doing nothing.
  Future<void> openExternal(Future<bool> Function() launch) async {
    bool ok;
    try {
      ok = await launch();
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      showSnack(s.errCannotLaunchApp, kind: SnackKind.error);
    }
  }

  void showSnack(String message, {SnackKind kind = SnackKind.info}) {
    final scheme = colors;
    final (icon, bg, fg) = switch (kind) {
      SnackKind.success => (
        Icons.check_circle_rounded,
        Colors.green.shade600,
        Colors.white,
      ),
      SnackKind.error => (
        Icons.error_outline_rounded,
        scheme.error,
        scheme.onError,
      ),
      SnackKind.info => (
        Icons.info_outline_rounded,
        scheme.inverseSurface,
        scheme.onInverseSurface,
      ),
    };
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
            Insets.x4, Insets.x3, Insets.x4, Insets.x4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.btn),
        ),
        elevation: 4,
        duration: AppDurations.snack,
        content: Row(
          children: [
            Icon(icon, color: fg, size: IconSz.sm),
            // Unqualified: inside an extension on BuildContext the receiver
            // *is* the context, and the sibling Responsive extension hangs off
            // the same type.
            gapW(Insets.x2h),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ));
  }
}

/// Any Arabic letter. Used to tell which language a server sentence is in —
/// the two languages this app ships use disjoint scripts, so script presence
/// answers it exactly, without a language-detection library.
final _arabicScript = RegExp(r'[؀-ۿ]');

extension ApiExceptionL10n on ApiException {
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
  String? _serverText(BuildContext context) {
    final raw = serverMessage?.trim();
    if (raw == null || raw.isEmpty) return null;

    final translated = ServerMessageL10n.translate(context.s, raw);
    if (translated != null) return translated;

    final wantsArabic = Localizations.localeOf(context).languageCode == 'ar';
    return _arabicScript.hasMatch(raw) == wantsArabic ? raw : null;
  }

  String localize(BuildContext context) {
    final s = context.s;
    switch (code) {
      case ApiErrorCode.invalidCredentials:
        return s.errInvalidCredentials;
      case ApiErrorCode.unauthorized:
        return s.errAuthRequired;
      case ApiErrorCode.permissionDenied:
        // An Odoo `AccessError` names what was refused ("you may not add
        // positions to this visit"); docs/API.md says to show it.
        return _serverText(context) ?? s.errPermissionDenied;
      case ApiErrorCode.timeout:
        return s.errNetworkTimeout;
      case ApiErrorCode.network:
        return s.errNetworkUnreachable;
      case ApiErrorCode.validation:
        return _serverText(context) ?? s.errValidation;
      case ApiErrorCode.notFound:
        return _serverText(context) ?? s.errNotFound;
      case ApiErrorCode.locationRequired:
        return s.errLocationRequired;
      case ApiErrorCode.server:
        return _serverText(context) ?? s.errServerError;
      case ApiErrorCode.locationPermission:
        return s.errLocationPermission;
      case ApiErrorCode.customerLoadFailed:
        return s.errCustomerLoadFailed;
      case ApiErrorCode.notSupported:
        return s.errFeatureNotAvailable;
      case ApiErrorCode.sessionRestoreFailed:
        return s.errSessionRestoreFailed;
      case ApiErrorCode.conflict:
        return _serverText(context) ?? s.errConflict;
      case ApiErrorCode.insecureConnection:
        return s.errInsecureConnection;
      case ApiErrorCode.unknown:
        // errUnknown, not errNetworkUnknown: this arm catches parse errors,
        // null casts and unclassified failures as well as network ones, and
        // "a network error occurred" sends the user off to check their WiFi
        // over what is usually a bug. `network` / `timeout` already carry the
        // genuinely connectivity-related cases.
        return _serverText(context) ?? s.errUnknown;
    }
  }
}
