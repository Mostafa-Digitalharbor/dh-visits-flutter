/// Why the server accepted the credentials but the app still refuses the
/// sign-in. Each reason has its own message: "invalid credentials" would send
/// the user retyping a password that is in fact correct.
enum LoginRejection {
  /// The account has two-step verification. Odoo's JSON sign-in answers
  /// `{"uid": null}` for it — a web-only login the app cannot complete.
  twoFactorRequired,

  /// The account holds no `dh_visit_management` role (and is not the Odoo
  /// administrator), so every visit call would be refused later on.
  noVisitRole,
}

/// Thrown by `AuthRepository.login` for a [LoginRejection]. The server-side
/// session it opened has already been discarded.
class LoginRejectedException implements Exception {
  final LoginRejection reason;
  const LoginRejectedException(this.reason);

  @override
  String toString() => 'LoginRejectedException(${reason.name})';
}
