import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../../l10n/generated/app_localizations.dart';

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
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 4,
        duration: const Duration(seconds: 3),
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
      case ApiErrorCode.unknown:
        return serverMessage ?? s.errNetworkUnknown;
    }
  }
}
