import 'package:flutter/material.dart';

import '../../core/api/api_exceptions.dart';
import '../../l10n/generated/app_localizations.dart';

extension AppContext on BuildContext {
  AppLocalizations get s => AppLocalizations.of(this);
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;

  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
