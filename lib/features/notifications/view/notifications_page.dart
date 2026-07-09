import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
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
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.status == NotificationsStatus.failure) {
            return ErrorView(
              message: state.error?.localize(context) ?? context.s.errUnknown,
              onRetry: () => context.read<NotificationsCubit>().load(),
            );
          }
          if (state.status == NotificationsStatus.loading &&
              state.activities.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.activities.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<NotificationsCubit>().load(),
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  EmptyView(
                    icon: Icons.notifications_none_rounded,
                    message: context.s.wfNotificationsEmpty,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.activities.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _ActivityTile(activity: state.activities[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final VisitActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (activity.urgency) {
      ActivityUrgency.overdue => (Icons.error_outline, context.colors.error),
      ActivityUrgency.today => (Icons.today, Colors.orange.shade700),
      _ => (Icons.notifications_active_outlined, context.colors.primary),
    };
    final deadline = activity.deadline;
    final due = deadline != null
        ? context.s.wfNotificationsDue(DateFormat('MMM d').format(deadline))
        : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tone.withValues(alpha: 0.14),
        child: Icon(icon, color: tone),
      ),
      title: Text(activity.summary,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        if (activity.visitRef != null) activity.visitRef!,
        if (due != null) due,
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: activity.visitId == 0
          ? null
          : () async {
              await context.push('/visits/${activity.visitId}');
              if (context.mounted) {
                // Refresh: the activity is likely cleared after acting.
                context.read<NotificationsCubit>().load();
              }
            },
    );
  }
}
