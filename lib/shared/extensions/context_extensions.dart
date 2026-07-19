import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/design/app_dimens.dart';

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
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.btn),
        ),
        elevation: 4,
        duration: AppDurations.snack,
        content: Row(
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: 10),
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

extension ApiExceptionL10n on ApiException {
  String localize(BuildContext context) {
    final s = context.s;
    switch (code) {
      case ApiErrorCode.invalidCredentials:
        return s.errInvalidCredentials;
      case ApiErrorCode.unauthorized:
        return s.errAuthRequired;
      case ApiErrorCode.permissionDenied:
        return s.errPermissionDenied;
      case ApiErrorCode.timeout:
        return s.errNetworkTimeout;
      case ApiErrorCode.network:
        return s.errNetworkUnreachable;
      case ApiErrorCode.validation:
        return serverMessage ?? s.errValidation;
      case ApiErrorCode.notFound:
        return serverMessage ?? s.errNotFound;
      case ApiErrorCode.locationRequired:
        return s.errLocationRequired;
      case ApiErrorCode.server:
        return serverMessage ?? s.errServerError;
      case ApiErrorCode.locationPermission:
        return s.errLocationPermission;
      case ApiErrorCode.customerLoadFailed:
        return s.errCustomerLoadFailed;
      case ApiErrorCode.notSupported:
        return s.errFeatureNotAvailable;
      case ApiErrorCode.sessionRestoreFailed:
        return s.errSessionRestoreFailed;
      case ApiErrorCode.conflict:
        return serverMessage ?? s.errConflict;
      case ApiErrorCode.insecureConnection:
        return s.errInsecureConnection;
      case ApiErrorCode.unknown:
        // errUnknown, not errNetworkUnknown: this arm catches parse errors,
        // null casts and unclassified failures as well as network ones, and
        // "a network error occurred" sends the user off to check their WiFi
        // over what is usually a bug. `network` / `timeout` already carry the
        // genuinely connectivity-related cases.
        return serverMessage ?? s.errUnknown;
    }
  }
}
