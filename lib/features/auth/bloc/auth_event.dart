part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  final String login;
  final String password;
  const AuthLoginRequested({required this.login, required this.password});

  @override
  List<Object?> get props => [login, password];
}

class AuthLogoutRequested extends AuthEvent {
  /// Why the session ended, when it wasn't the user's own choice — a 401 from
  /// the server, say. Carried through to the login screen so it can explain
  /// what happened instead of silently appearing mid-task.
  final ApiException? reason;

  const AuthLogoutRequested({this.reason});

  @override
  List<Object?> get props => [reason];
}

/// Raised when the user saves a (new) backend on the setup screen. Drops any
/// stored session locally so they always land on the login screen for the
/// freshly selected server.
class AuthServerChanged extends AuthEvent {
  const AuthServerChanged();
}
