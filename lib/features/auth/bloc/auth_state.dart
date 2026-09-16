part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, authenticating }

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthUser? user;

  /// Why the last sign-in failed, or why the session ended (a 401, a session
  /// that could not be restored). Cleared by [AuthNoticeShown] once a screen
  /// has shown it, so the next screen does not repeat it.
  final ApiException? error;

  /// A sign-in the server accepted but the app refused. See [LoginRejection].
  final LoginRejection? rejection;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.rejection,
  });

  const AuthState.unknown() : this();
  const AuthState.unauthenticated({
    ApiException? error,
    LoginRejection? rejection,
  }) : this(
          status: AuthStatus.unauthenticated,
          error: error,
          rejection: rejection,
        );
  const AuthState.authenticating()
      : this(status: AuthStatus.authenticating);
  const AuthState.authenticated(AuthUser user)
      : this(status: AuthStatus.authenticated, user: user);

  /// Whether there is something the signed-out screens must tell the user.
  bool get hasNotice => error != null || rejection != null;

  /// A copy with the notice removed and everything else kept.
  AuthState withoutNotice() => AuthState(status: status, user: user);

  @override
  List<Object?> get props => [status, user, error, rejection];
}
