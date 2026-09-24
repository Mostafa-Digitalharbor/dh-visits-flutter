import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design/app_dimens.dart';
import '../../../app/design/responsive.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/location/location_service.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/user_time.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../bloc/workday_cubit.dart';
import '../data/workday_tracker.dart';
import 'workday_disclosure_dialog.dart';

/// Start / End work day, under the app bar of the employee shell.
///
/// While a work day is open the employee's route is recorded continuously,
/// in the background too, so the bar also says so for as long as it lasts —
/// the in-app counterpart of the ongoing Android notification.
///
/// Renders nothing where work-day tracking is not wired in (widget tests) or
/// not available on the connected server.
class WorkdayBar extends StatelessWidget {
  const WorkdayBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = slMaybe<WorkdayTracker>();
    final location = slMaybe<LocationService>();
    if (tracker == null || location == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => WorkdayCubit(
        tracker: tracker,
        locationService: location,
        prefs: slMaybe<SharedPreferences>(),
      ),
      child: const _WorkdayBarBody(),
    );
  }
}

class _WorkdayBarBody extends StatelessWidget {
  const _WorkdayBarBody();

  Future<void> _onEvent(BuildContext context, WorkdayState state) async {
    final s = context.s;
    switch (state.outcome) {
      case WorkdayOutcome.started:
        context.showSnack(s.workdayStarted, kind: SnackKind.success);
      case WorkdayOutcome.ended:
        context.showSnack(s.workdayEnded, kind: SnackKind.success);
      case WorkdayOutcome.endQueued:
        context.showSnack(s.workdayEndQueued);
      case null:
        break;
    }
    switch (state.problem) {
      case WorkdayProblem.permissionDenied:
        context.showSnack(s.workdayLocationDenied, kind: SnackKind.error);
      case WorkdayProblem.permissionDeniedForever:
        final open = await ConfirmDialog.show(
          context,
          title: s.workdayStart,
          message: s.workdayLocationDeniedForever,
          confirmLabel: s.workdayOpenSettings,
          icon: Symbols.location_off,
        );
        if (open) await sl<LocationService>().openAppSettings();
      case WorkdayProblem.serviceDisabled:
        context.showSnack(s.workdayLocationServiceOff, kind: SnackKind.error);
      case WorkdayProblem.preciseLocationOff:
        final open = await ConfirmDialog.show(
          context,
          title: s.workdayStart,
          message: s.workdayPreciseOff,
          confirmLabel: s.workdayOpenSettings,
          icon: Symbols.location_searching,
        );
        if (open) await sl<LocationService>().openAppSettings();
      case WorkdayProblem.locationUnavailable:
        context.showSnack(s.errLocationUnavailable, kind: SnackKind.error);
      case WorkdayProblem.unsupported:
        context.showSnack(s.workdayUnsupported, kind: SnackKind.error);
      case WorkdayProblem.failed:
        context.showSnack(
          state.error?.localize(context) ?? s.errUnknown,
          kind: SnackKind.error,
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkdayCubit, WorkdayState>(
      listenWhen: (a, b) => a.eventSeq != b.eventSeq,
      listener: _onEvent,
      builder: (context, state) {
        final status = state.status;
        final phase = status.phase;
        if (phase == WorkdayPhase.unknown || phase == WorkdayPhase.unsupported) {
          return const SizedBox.shrink();
        }
        final s = context.s;
        final cs = context.colors;
        final active = status.isActive;
        final accent = active ? Colors.green.shade600 : cs.onSurfaceVariant;
        final cubit = context.read<WorkdayCubit>();

        final String title;
        String? subtitle;
        if (active) {
          final started = status.startedAt;
          title = s.workdayActiveSince(started == null
              ? '—'
              : AppDate.timeFormat(context).format(context.toUserTime(started)));
          if (!status.capturing) {
            subtitle = s.workdayCaptureOff;
          } else if (status.pending > 0) {
            subtitle = s.workdayPending(status.pending);
          }
        } else {
          title = s.workdayNotStarted;
          if (status.pending > 0) subtitle = s.workdayPending(status.pending);
        }

        final Widget action;
        if (state.busy) {
          action = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (active && !status.capturing) {
          action = TextButton(
            onPressed: () async {
              // Resuming records in the background: disclosure first, as on Start.
              if (!cubit.disclosureAccepted) {
                if (!await WorkdayDisclosureDialog.show(context)) return;
                await cubit.acceptDisclosure();
              }
              await cubit.resumeCapture(
                notificationTitle: s.workdayNotificationTitle,
                notificationText: s.workdayNotificationText,
              );
            },
            child: Text(s.commonRetry),
          );
        } else if (active) {
          action = OutlinedButton.icon(
            onPressed: () async {
              final ok = await ConfirmDialog.show(
                context,
                title: s.workdayEndConfirmTitle,
                message: s.workdayEndConfirmMessage,
                confirmLabel: s.workdayEnd,
                icon: Symbols.work_off,
              );
              if (ok) await cubit.end();
            },
            icon: const Icon(Symbols.stop_circle, size: 18),
            label: Text(s.workdayEnd),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.error,
            ),
          );
        } else {
          action = FilledButton.icon(
            onPressed: () async {
              // Disclosure first, before any permission prompt.
              if (!cubit.disclosureAccepted) {
                if (!await WorkdayDisclosureDialog.show(context)) return;
                await cubit.acceptDisclosure();
              }
              await cubit.start(
                notificationTitle: s.workdayNotificationTitle,
                notificationText: s.workdayNotificationText,
              );
            },
            icon: const Icon(Symbols.play_arrow, size: 18),
            label: Text(s.workdayStart),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.green.shade600,
            ),
          );
        }

        return Material(
          color: cs.surface,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(active ? Symbols.share_location : Symbols.work_history,
                    color: accent, size: 22, fill: active ? 1 : 0),
                context.gapW(Insets.x2h),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: active ? accent : cs.onSurface,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: active && !status.capturing
                                ? cs.error
                                : cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                context.gapW(Insets.x2),
                action,
              ],
            ),
          ),
        );
      },
    );
  }
}
