import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/connectivity_status.dart';
import '../../../core/network/refresh_failure.dart';
import '../../../shared/extensions/bloc_extensions.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/bloc/visits_list_bloc.dart';

/// Reloads the nearest [VisitsListBloc] over the whole team and completes when
/// the reload does, so a pull-to-refresh spinner lasts exactly as long as the
/// request.
///
/// The dashboard and analytics tabs had identical private copies of this. Both
/// blocs are built once and kept alive by the shell's stack, so without an
/// explicit reload stale figures could only be cleared by switching tabs.
Future<void> reloadTeamVisits(BuildContext context) {
  final bloc = context.read<VisitsListBloc>()
    ..add(const VisitsListLoadRequested(scope: VisitListScope.team));
  return bloc.untilSettled((s) => s.status == VisitsListStatus.loading);
}

/// Says so when a reload of the nearest [VisitsListBloc] fails while earlier
/// data is still on screen.
///
/// The screens built on that bloc (dashboard, analytics, route, review) keep
/// the last good figures on a failed refresh rather than blanking — a full
/// error view is only for "nothing loaded at all". Without this the failure
/// was silent: the pull-to-refresh spinner stopped and the stale numbers read
/// as current.
///
/// Quiet while its screen is hidden (a shell tab kept alive offstage), so one
/// failure never produces a snackbar per screen.
class VisitsRefreshFailureListener extends StatelessWidget {
  final Widget child;
  const VisitsRefreshFailureListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final shown = Visibility.of(context);
    return BlocListener<VisitsListBloc, VisitsListState>(
      listenWhen: (previous, next) =>
          shown &&
          next.status == VisitsListStatus.failure &&
          previous.status != VisitsListStatus.failure &&
          next.items.isNotEmpty &&
          (next.error?.worthAnnouncing(slMaybe<ConnectivityStatus>()) ?? true),
      listener: (context, state) =>
          context.showStaleRefreshSnack(state.error),
      child: child,
    );
  }
}

/// An [EmptyView] that can still be pulled to refresh.
///
/// A `RefreshIndicator` only reacts to a scrollable child, and an empty state
/// is not one — so an empty screen had no way to reload short of leaving it.
/// This fills the viewport with an always-scrollable view around the message.
class RefreshableEmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const RefreshableEmptyView({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: box.maxHeight,
          child: EmptyView(icon: icon, message: message),
        ),
      ),
    );
  }
}
