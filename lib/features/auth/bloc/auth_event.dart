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
  const AuthLogoutRequested();
}

/// Raised when the user saves a (new) backend on the setup screen. Drops any
/// stored session locally so they always land on the login screen for the
/// freshly selected server.
class AuthServerChanged extends AuthEvent {
  const AuthServerChanged();
}
