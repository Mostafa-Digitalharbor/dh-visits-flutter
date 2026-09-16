import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../core/constants.dart';

extension AwaitSettled<S> on StateStreamable<S> {
  /// Completes once a state *after this call* satisfies `!isBusy`, or after
  /// [timeout]. Never throws.
  ///
  /// For pull-to-refresh: `onRefresh` must return a future that lasts as long
  /// as the reload, or the spinner vanishes the instant the event is added and
  /// the user can't tell whether anything happened. Bounded, because a bloc
  /// that decides not to reload (same scope, already loading) emits nothing.
  Future<void> untilSettled(
    bool Function(S state) isBusy, {
    Duration timeout = AppConstants.refreshTimeout,
  }) async {
    try {
      await stream.firstWhere((s) => !isBusy(s)).timeout(timeout);
    } on TimeoutException {
      // The reload is still running; the gesture just stops waiting for it.
    } on StateError {
      // The bloc closed (screen left) before settling.
    }
  }
}
