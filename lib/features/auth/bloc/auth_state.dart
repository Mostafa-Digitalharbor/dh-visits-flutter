part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, authenticating }

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthUser? user;
  final ApiException? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  const AuthState.unknown() : this();
  const AuthState.unauthenticated({ApiException? error})
      : this(status: AuthStatus.unauthenticated, error: error);
  const AuthState.authenticating()
      : this(status: AuthStatus.authenticating);
  const AuthState.authenticated(AuthUser user)
      : this(status: AuthStatus.authenticated, user: user);

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    ApiException? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  @override
  List<Object?> get props => [status, user, error];
}
