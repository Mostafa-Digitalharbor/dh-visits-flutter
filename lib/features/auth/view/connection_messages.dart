import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/config/server_config_cubit.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../bloc/auth_bloc.dart';
import '../data/login_rejection.dart';

/// The sentences the sign-in flow shows when the server or the account is the
/// problem.
///
/// The app-wide `localize()` is written for users already inside the app, who
/// know their server works ("Cannot reach the server"). On the server and
/// login screens the address itself is the likeliest culprit, so these name
/// the host and tell the user what to check.
abstract final class ConnectionMessages {
  /// Why reaching or signing in to [host] failed, and what to do about it.
  static String forFailure(
    BuildContext context,
    ApiException error, {
    required String host,
  }) {
    final s = context.s;
    if (ServerConfigCubit.isCertificateFailure(error)) {
      return s.serverSetupUntrustedCertificate(host);
    }
    return switch (error.code) {
      ApiErrorCode.network => s.serverSetupUnreachable(host),
      ApiErrorCode.timeout => s.serverSetupTimeout(host),
      // A missing `/web/*` route, a login wall or an unreadable body: on these
      // screens every one of them means "this address is not Odoo".
      ApiErrorCode.invalidResponse ||
      ApiErrorCode.notSupported ||
      ApiErrorCode.notFound =>
        s.serverSetupNotOdoo(host),
      ApiErrorCode.serverUnavailable ||
      ApiErrorCode.server =>
        s.serverSetupServerDown(host),
      ApiErrorCode.invalidCredentials => s.loginInvalidCredentials,
      // Only reaches the login screen as the reason a session ended.
      ApiErrorCode.unauthorized => s.loginSessionEnded,
      _ => error.localize(context),
    };
  }

  /// The notice [state] carries for the signed-out screens, or null.
  static String? forState(BuildContext context, AuthState state) {
    final rejection = state.rejection;
    if (rejection != null) return forRejection(context, rejection);
    final error = state.error;
    if (error == null) return null;
    return forFailure(
      context,
      error,
      host: context.read<ServerConfigCubit>().state.host,
    );
  }

  /// Whether a transition between two auth states raised a new notice.
  static bool raisedNotice(AuthState previous, AuthState next) =>
      next.hasNotice &&
      (previous.error != next.error || previous.rejection != next.rejection);

  /// Why an accepted sign-in was still refused.
  static String forRejection(BuildContext context, LoginRejection reason) =>
      switch (reason) {
        LoginRejection.twoFactorRequired => context.s.loginTwoFactorUnsupported,
        LoginRejection.noVisitRole => context.s.loginNoVisitRole,
      };
}
