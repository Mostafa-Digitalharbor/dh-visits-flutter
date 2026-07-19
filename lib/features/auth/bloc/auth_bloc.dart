import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/auth_repository.dart';
import '../data/models/user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  /// Optional hook run *before* the session is destroyed on logout — used to
  /// unregister the FCM device token while the request is still authorised.
  /// Best-effort: its failure never blocks logout.
  final Future<void> Function()? onBeforeLogout;

  AuthBloc({required this.repository, this.onBeforeLogout})
      : super(const AuthState.unknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthServerChanged>(_onServerChanged);
  }

  /// Minimum time the splash screen stays visible so its zoom animation can
  /// play to completion before we navigate away.
  static const _minSplashDuration = Duration(milliseconds: 2000);

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final clock = Stopwatch()..start();
    AuthUser? user;
    ApiException? restoreError;
    try {
      user = await repository.currentUser();
    } catch (e) {
      // Reading the stored session can fail outright — a corrupted Android
      // keystore after a device restore makes FlutterSecureStorage throw, and a
      // changed payload shape breaks AuthUser.fromJson. Without this catch no
      // state is ever emitted and the router pins the user to /splash forever.
      // Treat it as "no session" and tell them why on the login screen.
      debugPrint('[debug] AuthBloc._onStarted: session restore failed ($e)');
      restoreError = ApiException.sessionRestoreFailed(e);
    }
    final remaining = _minSplashDuration - clock.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (user == null) {
      emit(AuthState.unauthenticated(error: restoreError));
    } else {
      emit(AuthState.authenticated(user));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('[debug] AuthBloc._onLoginRequested: login=${event.login}');
    emit(const AuthState.authenticating());
    try {
      final user = await repository.login(
        login: event.login,
        password: event.password,
      );
      debugPrint(
          '[debug] AuthBloc: login succeeded uid=${user.uid} '
          'employeeId=${user.employeeId} '
          'isAdmin=${user.isAdmin} isManager=${user.isManager} '
          'canEditVisits=${user.canEditVisits}');
      emit(AuthState.authenticated(user));
    } on ApiException catch (e) {
      debugPrint(
          '[debug] AuthBloc: ApiException code=${e.code} msg=${e.serverMessage}');
      emit(AuthState.unauthenticated(error: e));
    } catch (e, st) {
      debugPrint('[debug] AuthBloc: unexpected error: $e\n$st');
      emit(AuthState.unauthenticated(
          error: ApiException.unexpected(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (onBeforeLogout != null) {
      try {
        await onBeforeLogout!();
      } catch (e) {
        debugPrint('[debug] AuthBloc: onBeforeLogout failed: $e');
      }
    }
    await repository.logout();
    emit(AuthState.unauthenticated(error: event.reason));
  }

  Future<void> _onServerChanged(
    AuthServerChanged event,
    Emitter<AuthState> emit,
  ) async {
    await repository.clearLocalSession();
    emit(const AuthState.unauthenticated());
  }
}
