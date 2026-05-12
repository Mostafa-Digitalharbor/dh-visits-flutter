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
