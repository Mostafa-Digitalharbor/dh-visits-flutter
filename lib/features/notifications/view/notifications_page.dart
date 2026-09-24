import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/app_date.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/data/models/visit_activity.dart';
import '../../visits/data/visits_repository.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          NotificationsCubit(repository: sl<VisitsRepository>())..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.wfNotificationsTitle)),
      body: BlocConsumer<NotificationsCubit, NotificationsState>(
        // A refresh that fails over a feed already on screen keeps the feed;
        // this says so instead of letting the stale rows pass as current.
        listenWhen: (previous, next) =>
            next.status == NotificationsStatus.failure &&
            previous.status != NotificationsStatus.failure &&
            next.activities.isNotEmpty,
        listener: (context, state) =>
            context.showStaleRefreshSnack(state.error),
        builder: (context, state) => AsyncListView<VisitActivity>(
          items: state.activities,
          isLoading: state.status == NotificationsStatus.loading ||
              state.status == NotificationsStatus.initial,
          hasError: state.status == NotificationsStatus.failure,
          errorMessage: state.error?.localize(context),
          error: state.error,
          onRefresh: context.read<NotificationsCubit>().load,
          emptyIcon: Symbols.notifications_none,
          emptyMessage: context.s.wfNotificationsEmpty,
          separatorHeight: 0,
          padding: const EdgeInsetsDirectional.symmetric(vertical: Insets.x2),
          itemBuilder: (_, activity, __) => _ActivityTile(activity: activity),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final VisitActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final (icon, tone) = switch (activity.urgency) {
      ActivityUrgency.overdue => (Symbols.error, context.colors.error),
      ActivityUrgency.today => (Symbols.today, context.x.warning),
      _ => (Symbols.notifications_active, context.colors.primary),
    };
    final deadline = activity.deadline;
    final subtitle = context.joinFacts([
      activity.visitRef,
      if (deadline != null) s.wfNotificationsDue(AppDate.dayMonth(context, deadline)),
    ]);
    final title = activity.summary.isNotEmpty
        ? activity.summary
        : s.visitFallbackTitle(activity.visitId);

    return ListTile(
      leading: IconBadge(
        icon: icon,
        color: tone,
        radius: Radii.pill,
        size: context.r(CompSz.chip),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      // `chevron_right` mirrors itself in Arabic (`matchTextDirection`).
      trailing: const Icon(Symbols.chevron_right),
      onTap: () async {
        await context.push(AppRoutes.visitDetail(activity.visitId));
        if (context.mounted) {
          // Refresh: the activity is likely cleared after acting.
          context.read<NotificationsCubit>().load();
        }
      },
    );
  }
}
